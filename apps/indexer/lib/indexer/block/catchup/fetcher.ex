defmodule Indexer.Block.Catchup.Fetcher do
  @moduledoc """
  Fetches and indexes block ranges from the block before the latest block to genesis (0) that are missing.
  """

  use Spandex.Decorators

  require Logger

  import Indexer.Block.Fetcher,
    only: [
      async_import_blobs: 2,
      async_import_block_rewards: 2,
      async_import_celo_epoch_block_operations: 2,
      async_import_coin_balances: 2,
      async_import_created_contract_codes: 2,
      async_import_filecoin_addresses_info: 2,
      async_import_internal_transactions: 2,
      async_import_replaced_transactions: 2,
      async_import_signed_authorizations_statuses: 2,
      async_import_token_balances: 2,
      async_import_token_instances: 1,
      async_import_tokens: 2,
      async_import_uncles: 2,
      fetch_and_import_range: 2
    ]

  alias Ecto.Changeset
  alias EthereumJSONRPC.Utility.RangesHelper
  alias Explorer.Chain
  alias Explorer.Chain.NullRoundHeight
  alias Explorer.Utility.{MassiveBlock, MissingRangesManipulator}
  alias Indexer.{Block, Tracer}
  alias Indexer.Block.Catchup.TaskSupervisor
  alias Indexer.Fetcher.OnDemand.ContractCreator, as: ContractCreatorOnDemand
  alias Indexer.Prometheus

  @behaviour Block.Fetcher

  defstruct block_fetcher: nil,
            memory_monitor: nil

  @doc """
  Required named arguments

    * `:json_rpc_named_arguments` - `t:EthereumJSONRPC.json_rpc_named_arguments/0` passed to
        `EthereumJSONRPC.json_rpc/2`.
  """
  def task(state) do
    Logger.metadata(fetcher: :block_catchup)
    Process.flag(:trap_exit, true)

    case MissingRangesManipulator.get_latest_batch(blocks_batch_size() * blocks_concurrency()) do
      [] ->
        %{
          first_block_number: nil,
          last_block_number: nil,
          missing_block_count: 0,
          shrunk: false
        }

      missing_ranges ->
        first.._//_ = List.first(missing_ranges)
        _..last//_ = List.last(missing_ranges)

        Logger.metadata(first_block_number: first, last_block_number: last)

        missing_block_count =
          missing_ranges
          |> Stream.map(&Enum.count/1)
          |> Enum.sum()

        stream_fetch_and_import(state, missing_ranges)

        %{
          first_block_number: first,
          last_block_number: last,
          missing_block_count: missing_block_count,
          shrunk: false
        }
    end
  end

  @doc """
  The number of blocks to request in one call to the JSONRPC.  Defaults to
  10.  Block requests also include the transactions for those blocks.  *These transactions
  are not paginated.
  """
  def blocks_batch_size do
    Application.get_env(:indexer, __MODULE__)[:batch_size]
  end

  @doc """
  The number of concurrent requests of `blocks_batch_size` to allow against the JSONRPC.
  Defaults to 10.  So, up to `blocks_concurrency * block_batch_size` (defaults to
  `10 * 10`) blocks can be requested from the JSONRPC at once over all
  connections.  Up to `block_concurrency * receipts_batch_size * receipts_concurrency` (defaults to
  `#{10 * Block.Fetcher.default_receipts_batch_size() * Block.Fetcher.default_receipts_concurrency()}`
  ) receipts can be requested from the JSONRPC at once over all connections.
  """
  def blocks_concurrency do
    Application.get_env(:indexer, __MODULE__)[:concurrency]
  end

  @async_import_remaining_block_data_options ~w(address_hash_to_fetched_balance_block_number)a

  @impl Block.Fetcher
  def import(_block_fetcher, options) when is_map(options) do
    {async_import_remaining_block_data_options, options_with_block_rewards_errors} =
      Map.split(options, @async_import_remaining_block_data_options)

    {block_reward_errors, options_without_block_rewards_errors} =
      pop_in(options_with_block_rewards_errors[:block_rewards][:errors])

    full_chain_import_options =
      options_without_block_rewards_errors
      |> put_in([:blocks, :params, Access.all(), :consensus], true)
      |> put_in([:blocks, :params, Access.all(), :refetch_needed], false)

    with {:import, {:ok, imported} = ok} <- {:import, Chain.import(full_chain_import_options)} do
      async_import_remaining_block_data(
        imported,
        Map.put(async_import_remaining_block_data_options, :block_rewards, %{errors: block_reward_errors})
      )

      ContractCreatorOnDemand.async_update_cache_of_contract_creator_on_demand(imported)

      ok
    end
  end

  defp async_import_remaining_block_data(
         imported,
         %{block_rewards: %{errors: block_reward_errors}} = options
       ) do
    realtime? = false

    async_import_block_rewards(block_reward_errors, realtime?)
    async_import_coin_balances(imported, options)
    async_import_created_contract_codes(imported, realtime?)
    async_import_internal_transactions(imported, realtime?)
    async_import_tokens(imported, realtime?)
    async_import_token_balances(imported, realtime?)
    async_import_uncles(imported, realtime?)
    async_import_replaced_transactions(imported, realtime?)
    async_import_token_instances(imported)
    async_import_blobs(imported, realtime?)
    async_import_celo_epoch_block_operations(imported, realtime?)
    async_import_filecoin_addresses_info(imported, realtime?)
    async_import_signed_authorizations_statuses(imported, realtime?)
  end

  defp stream_fetch_and_import(state, ranges) do
    TaskSupervisor
    |> Task.Supervisor.async_stream(
      RangesHelper.split(ranges, blocks_batch_size()),
      &fetch_and_import_missing_range(state, &1),
      max_concurrency: blocks_concurrency(),
      timeout: :infinity,
      shutdown: Application.get_env(:indexer, :graceful_shutdown_period)
    )
    |> handle_fetch_and_import_results()
  end

  # Run at state.blocks_concurrency max_concurrency when called by `stream_import/1`
  @decorate trace(
              name: "fetch",
              resource: "Indexer.Block.Catchup.Fetcher.fetch_and_import_missing_range/3",
              tracer: Tracer
            )
  defp fetch_and_import_missing_range(
         %__MODULE__{block_fetcher: %Block.Fetcher{} = block_fetcher},
         first..last//_ = range
       ) do
    Logger.metadata(fetcher: :block_catchup, first_block_number: first, last_block_number: last)
    Process.flag(:trap_exit, true)

    {fetch_duration, result} = :timer.tc(fn -> fetch_and_import_range(block_fetcher, range) end)

    Prometheus.Instrumenter.block_full_process(fetch_duration, __MODULE__)

    case result do
      {:ok, %{errors: errors}} ->
        valid_errors = handle_null_rounds(errors)

        {:ok, %{range: range, errors: valid_errors}}

      {:error, {:import = step, [%Changeset{} | _] = changesets}} = error ->
        Prometheus.Instrumenter.import_errors()
        Logger.error(fn -> ["failed to validate: ", inspect(changesets), ". Retrying."] end, step: step)

        error

      {:error, {:import = step, reason}} = error ->
        Prometheus.Instrumenter.import_errors()
        Logger.error(fn -> [inspect(reason), ". Retrying."] end, step: step)
        if reason == :timeout, do: add_range_to_massive_blocks(range)

        error

      {:error, {step, reason}} = error ->
        Logger.error(
          fn ->
            ["failed to fetch: ", inspect(reason), ". Retrying."]
          end,
          step: step
        )

        error

      {:error, {step, failed_value, _changes_so_far}} = error ->
        Logger.error(
          fn ->
            ["failed to insert: ", inspect(failed_value), ". Retrying."]
          end,
          step: step
        )

        error
    end
  rescue
    exception ->
      if timeout_exception?(exception), do: add_range_to_massive_blocks(range)
      Logger.error(fn -> [Exception.format(:error, exception, __STACKTRACE__), ?\n, ?\n, "Retrying."] end)
      {:error, exception}
  end

  defp handle_fetch_and_import_results(results) do
    results
    |> Enum.reduce([], fn
      {:ok, {:ok, %{range: range, errors: errors}}}, acc ->
        success_numbers = Enum.to_list(range) -- Enum.map(errors, &block_error_to_number/1)
        success_numbers ++ acc

      _result, acc ->
        acc
    end)
    |> numbers_to_ranges()
    |> MissingRangesManipulator.clear_batch()
  end

  defp handle_null_rounds(errors) do
    {null_rounds, other_errors} =
      Enum.split_with(errors, fn
        %{message: "requested epoch was a null round"} -> true
        _ -> false
      end)

    null_rounds
    |> Enum.map(&block_error_to_number/1)
    |> NullRoundHeight.insert_heights()

    other_errors
  end

  defp timeout_exception?(%{message: message}) when is_binary(message) do
    String.match?(message, ~r/due to a timeout/)
  end

  defp timeout_exception?(_exception), do: false

  defp add_range_to_massive_blocks(range) do
    clear_missing_ranges(range)

    range
    |> Enum.to_list()
    |> MassiveBlock.insert_block_numbers()
  end

  defp clear_missing_ranges(initial_range, errors \\ []) do
    success_numbers = Enum.to_list(initial_range) -- Enum.map(errors, &block_error_to_number/1)

    success_numbers
    |> numbers_to_ranges()
    |> MissingRangesManipulator.clear_batch()
  end

  defp block_error_to_number(%{data: %{number: number}}) when is_integer(number), do: number

  defp numbers_to_ranges([]), do: []

  defp numbers_to_ranges(numbers) when is_list(numbers) do
    numbers
    |> Enum.sort(&>=/2)
    |> Enum.chunk_while(
      nil,
      fn
        number, nil ->
          {:cont, number..number}

        number, first..last//_ when number == last - 1 ->
          {:cont, first..number}

        number, range ->
          {:cont, range, number..number}
      end,
      fn range -> {:cont, range, nil} end
    )
  end
end
