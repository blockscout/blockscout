defmodule Indexer.Block.Catchup.Fetcher do
  @moduledoc """
  Fetches and indexes block ranges from the block before the latest block to genesis (0) that are missing.
  """

  use Spandex.Decorators

  require Logger

  import Indexer.Block.Fetcher,
    only: [
      async_import_block_rewards: 1,
      async_import_coin_balances: 2,
      async_import_created_contract_codes: 1,
      async_import_internal_transactions: 1,
      async_import_replaced_transactions: 1,
      async_import_tokens: 1,
      async_import_token_balances: 1,
      async_import_token_instances: 1,
      async_import_uncles: 1,
      fetch_and_import_range: 2
    ]

  alias Ecto.Changeset
  alias Explorer.Chain
  alias Indexer.{Block, Tracer}
  alias Indexer.Block.Catchup.Sequence
  alias Indexer.Memory.Shrinkable

  @behaviour Block.Fetcher

  # These are all the *default* values for options.
  # DO NOT use them directly in the code.  Get options from `state`.

  @blocks_batch_size 5
  @blocks_concurrency 5
  @sequence_name :block_catchup_sequencer

  defstruct blocks_batch_size: @blocks_batch_size,
            blocks_concurrency: @blocks_concurrency,
            block_fetcher: nil,
            memory_monitor: nil

  @doc false
  def default_blocks_batch_size, do: @blocks_batch_size

  @doc """
  Required named arguments

    * `:json_rpc_named_arguments` - `t:EthereumJSONRPC.json_rpc_named_arguments/0` passed to
        `EthereumJSONRPC.json_rpc/2`.

  The follow options can be overridden:

    * `:blocks_batch_size` - The number of blocks to request in one call to the JSONRPC.  Defaults to
      `#{@blocks_batch_size}`.  Block requests also include the transactions for those blocks.  *These transactions
      are not paginated.*
    * `:blocks_concurrency` - The number of concurrent requests of `:blocks_batch_size` to allow against the JSONRPC.
      Defaults to #{@blocks_concurrency}.  So, up to `blocks_concurrency * block_batch_size` (defaults to
      `#{@blocks_concurrency * @blocks_batch_size}`) blocks can be requested from the JSONRPC at once over all
      connections.  Up to `block_concurrency * receipts_batch_size * receipts_concurrency` (defaults to
      `#{@blocks_concurrency * Block.Fetcher.default_receipts_batch_size() * Block.Fetcher.default_receipts_batch_size()}`
      ) receipts can be requested from the JSONRPC at once over all connections.

  """
  def task(
        %__MODULE__{
          blocks_batch_size: blocks_batch_size,
          block_fetcher: %Block.Fetcher{json_rpc_named_arguments: json_rpc_named_arguments}
        } = state
      ) do
    Logger.metadata(fetcher: :block_catchup)

    with {:ok, latest_block_number} <- fetch_last_block(json_rpc_named_arguments) do
      case latest_block_number do
        # let realtime indexer get the genesis block
        0 ->
          %{first_block_number: 0, missing_block_count: 0, last_block_number: 0, shrunk: false}

        _ ->
          # realtime indexer gets the current latest block
          first = latest_block_number - 1
          last = last_block()

          Logger.metadata(first_block_number: first, last_block_number: last)

          missing_ranges = Chain.missing_block_number_ranges(first..last)

          range_count = Enum.count(missing_ranges)

          missing_block_count =
            missing_ranges
            |> Stream.map(&Enum.count/1)
            |> Enum.sum()

          Logger.debug(fn -> "Missed blocks in ranges." end,
            missing_block_range_count: range_count,
            missing_block_count: missing_block_count
          )

          shrunk =
            case missing_block_count do
              0 ->
                false

              _ ->
                step = step(first, last, blocks_batch_size)
                sequence_opts = put_memory_monitor([ranges: missing_ranges, step: step], state)
                gen_server_opts = [name: @sequence_name]
                {:ok, sequence} = Sequence.start_link(sequence_opts, gen_server_opts)
                Sequence.cap(sequence)

                stream_fetch_and_import(state, sequence)

                Shrinkable.shrunk?(sequence)
            end

          %{
            first_block_number: first,
            last_block_number: last,
            missing_block_count: missing_block_count,
            shrunk: shrunk
          }
      end
    end
  end

  defp fetch_last_block(json_rpc_named_arguments) do
    case latest_block() do
      nil ->
        EthereumJSONRPC.fetch_block_number_by_tag("latest", json_rpc_named_arguments)

      number ->
        {:ok, number}
    end
  end

  defp step(first, last, blocks_batch_size) do
    if first < last, do: blocks_batch_size, else: -1 * blocks_batch_size
  end

  @async_import_remaining_block_data_options ~w(address_hash_to_fetched_balance_block_number)a

  @impl Block.Fetcher
  def import(_block_fetcher, options) when is_map(options) do
    {async_import_remaining_block_data_options, options_with_block_rewards_errors} =
      Map.split(options, @async_import_remaining_block_data_options)

    {block_reward_errors, options_without_block_rewards_errors} =
      pop_in(options_with_block_rewards_errors[:block_rewards][:errors])

    full_chain_import_options =
      put_in(options_without_block_rewards_errors, [:blocks, :params, Access.all(), :consensus], true)

    with {:import, {:ok, imported} = ok} <- {:import, Chain.import(full_chain_import_options)} do
      async_import_remaining_block_data(
        imported,
        Map.put(async_import_remaining_block_data_options, :block_rewards, %{errors: block_reward_errors})
      )

      ok
    end
  end

  defp async_import_remaining_block_data(
         imported,
         %{block_rewards: %{errors: block_reward_errors}} = options
       ) do
    async_import_block_rewards(block_reward_errors)
    async_import_coin_balances(imported, options)
    async_import_created_contract_codes(imported)
    async_import_internal_transactions(imported)
    async_import_tokens(imported)
    async_import_token_balances(imported)
    async_import_uncles(imported)
    async_import_replaced_transactions(imported)
    async_import_token_instances(imported)
  end

  defp stream_fetch_and_import(%__MODULE__{blocks_concurrency: blocks_concurrency} = state, sequence)
       when is_pid(sequence) do
    sequence
    |> Sequence.build_stream()
    |> Task.async_stream(
      &fetch_and_import_range_from_sequence(state, &1, sequence),
      max_concurrency: blocks_concurrency,
      timeout: :infinity
    )
    |> Stream.run()
  end

  # Run at state.blocks_concurrency max_concurrency when called by `stream_import/1`
  @decorate trace(
              name: "fetch",
              resource: "Indexer.Block.Catchup.Fetcher.fetch_and_import_range_from_sequence/3",
              tracer: Tracer
            )
  defp fetch_and_import_range_from_sequence(
         %__MODULE__{block_fetcher: %Block.Fetcher{} = block_fetcher},
         first..last = range,
         sequence
       ) do
    Logger.metadata(fetcher: :block_catchup, first_block_number: first, last_block_number: last)

    case fetch_and_import_range(block_fetcher, range) do
      {:ok, %{inserted: inserted, errors: errors}} ->
        errors = cap_seq(sequence, errors)
        retry(sequence, errors)

        {:ok, inserted: inserted}

      {:error, {:import = step, [%Changeset{} | _] = changesets}} = error ->
        Logger.error(fn -> ["failed to validate: ", inspect(changesets), ". Retrying."] end, step: step)

        push_back(sequence, range)

        error

      {:error, {:import = step, reason}} = error ->
        Logger.error(fn -> [inspect(reason), ". Retrying."] end, step: step)

        push_back(sequence, range)

        error

      {:error, {step, reason}} = error ->
        Logger.error(
          fn ->
            ["failed to fetch: ", inspect(reason), ". Retrying."]
          end,
          step: step
        )

        push_back(sequence, range)

        error

      {:error, {step, failed_value, _changes_so_far}} = error ->
        Logger.error(
          fn ->
            ["failed to insert: ", inspect(failed_value), ". Retrying."]
          end,
          step: step
        )

        push_back(sequence, range)

        error
    end
  rescue
    exception ->
      Logger.error(fn -> [Exception.format(:error, exception, __STACKTRACE__), ?\n, ?\n, "Retrying."] end)

      push_back(sequence, range)

      {:error, exception}
  end

  defp cap_seq(seq, errors) do
    {not_founds, other_errors} =
      Enum.split_with(errors, fn
        %{code: 404, data: %{number: _}} -> true
        _ -> false
      end)

    case not_founds do
      [] ->
        Logger.debug("got blocks")

        other_errors

      _ ->
        Sequence.cap(seq)
    end

    other_errors
  end

  defp push_back(sequence, range) do
    case Sequence.push_back(sequence, range) do
      :ok -> :ok
      {:error, reason} -> Logger.error(fn -> ["Could not push back to Sequence: ", inspect(reason)] end)
    end
  end

  defp retry(sequence, block_errors) when is_list(block_errors) do
    block_errors
    |> block_errors_to_block_number_ranges()
    |> Enum.map(&push_back(sequence, &1))
  end

  defp block_errors_to_block_number_ranges(block_errors) when is_list(block_errors) do
    block_errors
    |> Enum.map(&block_error_to_number/1)
    |> numbers_to_ranges()
  end

  defp block_error_to_number(%{data: %{number: number}}) when is_integer(number), do: number

  defp numbers_to_ranges([]), do: []

  defp numbers_to_ranges(numbers) when is_list(numbers) do
    numbers
    |> Enum.sort()
    |> Enum.chunk_while(
      nil,
      fn
        number, nil ->
          {:cont, number..number}

        number, first..last when number == last + 1 ->
          {:cont, first..number}

        number, range ->
          {:cont, range, number..number}
      end,
      fn range -> {:cont, range} end
    )
  end

  defp put_memory_monitor(sequence_options, %__MODULE__{memory_monitor: nil}) when is_list(sequence_options),
    do: sequence_options

  defp put_memory_monitor(sequence_options, %__MODULE__{memory_monitor: memory_monitor})
       when is_list(sequence_options) do
    Keyword.put(sequence_options, :memory_monitor, memory_monitor)
  end

  @doc """
  Puts a list of block numbers to the front of the sequencing queue.
  """
  @spec push_front([non_neg_integer()]) :: :ok | {:error, :queue_unavailable | :maximum_size | String.t()}
  def push_front(block_numbers) do
    if Process.whereis(@sequence_name) do
      Enum.reduce_while(block_numbers, :ok, fn block_number, :ok ->
        if is_integer(block_number) do
          case Sequence.push_front(@sequence_name, block_number..block_number) do
            :ok -> {:cont, :ok}
            {:error, _} = error -> {:halt, error}
          end
        else
          Logger.warn(fn -> ["Received a non-integer block number: ", inspect(block_number)] end)
        end
      end)
    else
      {:error, :queue_unavailable}
    end
  end

  defp last_block do
    string_value = Application.get_env(:indexer, :first_block)

    case Integer.parse(string_value) do
      {integer, ""} ->
        integer

      _ ->
        min_missing_block_number =
          "min_missing_block_number"
          |> Chain.get_last_fetched_counter()
          |> Decimal.to_integer()

        min_missing_block_number
    end
  end

  defp latest_block do
    string_value = Application.get_env(:indexer, :last_block)

    case Integer.parse(string_value) do
      {integer, ""} -> integer
      _ -> nil
    end
  end
end
