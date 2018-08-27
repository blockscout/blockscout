defmodule Indexer.BlockFetcher.Catchup do
  @moduledoc """
  Fetches and indexes block ranges from the block before the latest block to genesis (0) that are missing.
  """

  require Logger

  import Indexer.BlockFetcher, only: [fetch_and_import_range: 2]

  alias Explorer.Chain

  alias Indexer.{
    BalanceFetcher,
    BlockFetcher,
    InternalTransactionFetcher,
    Sequence,
    TokenFetcher
  }

  @behaviour BlockFetcher

  # These are all the *default* values for options.
  # DO NOT use them directly in the code.  Get options from `state`.

  @blocks_batch_size 10
  @blocks_concurrency 10

  defstruct blocks_batch_size: @blocks_batch_size,
            blocks_concurrency: @blocks_concurrency,
            block_fetcher: nil

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
      Defaults to #{@blocks_concurrency}.  So upto `blocks_concurrency * block_batch_size` (defaults to
      `#{@blocks_concurrency * @blocks_batch_size}`) blocks can be requested from the JSONRPC at once over all
      connections.  Upto `block_concurrency * receipts_batch_size * receipts_concurrency` (defaults to
      `#{@blocks_concurrency * BlockFetcher.default_receipts_batch_size() * BlockFetcher.default_receipts_batch_size()}`
      ) receipts can be requested from the JSONRPC at once over all connections.

  """
  def task(
        %__MODULE__{
          blocks_batch_size: blocks_batch_size,
          block_fetcher: %BlockFetcher{json_rpc_named_arguments: json_rpc_named_arguments}
        } = state
      ) do
    {:ok, latest_block_number} = EthereumJSONRPC.fetch_block_number_by_tag("latest", json_rpc_named_arguments)

    case latest_block_number do
      # let realtime indexer get the genesis block
      0 ->
        %{first_block_number: 0, missing_block_count: 0}

      _ ->
        # realtime indexer gets the current latest block
        first = latest_block_number - 1
        last = 0
        missing_ranges = Chain.missing_block_number_ranges(first..last)
        range_count = Enum.count(missing_ranges)

        missing_block_count =
          missing_ranges
          |> Stream.map(&Enum.count/1)
          |> Enum.sum()

        Logger.debug(fn ->
          "#{missing_block_count} missed blocks in #{range_count} ranges between #{first} and #{last}"
        end)

        case missing_block_count do
          0 ->
            :ok

          _ ->
            {:ok, sequence} = Sequence.start_link(ranges: missing_ranges, step: -1 * blocks_batch_size)
            Sequence.cap(sequence)

            stream_fetch_and_import(state, sequence)
        end

        %{first_block_number: first, missing_block_count: missing_block_count}
    end
  end

  @async_import_remaning_block_data_options ~w(address_hash_to_fetched_balance_block_number transaction_hash_to_block_number)a

  @impl BlockFetcher
  def import(_, options) when is_map(options) do
    {async_import_remaning_block_data_options, chain_import_options} =
      Map.split(options, @async_import_remaning_block_data_options)

    with {:ok, results} = ok <- Chain.import(chain_import_options) do
      async_import_remaining_block_data(
        results,
        async_import_remaning_block_data_options
      )

      ok
    end
  end

  defp async_import_remaining_block_data(
         %{transactions: transaction_hashes, addresses: address_hashes, tokens: tokens},
         %{
           address_hash_to_fetched_balance_block_number: address_hash_to_block_number,
           transaction_hash_to_block_number: transaction_hash_to_block_number
         }
       ) do
    address_hashes
    |> Enum.map(fn address_hash ->
      block_number = Map.fetch!(address_hash_to_block_number, to_string(address_hash))
      %{address_hash: address_hash, block_number: block_number}
    end)
    |> BalanceFetcher.async_fetch_balances()

    transaction_hashes
    |> Enum.map(fn transaction_hash ->
      block_number = Map.fetch!(transaction_hash_to_block_number, to_string(transaction_hash))
      %{block_number: block_number, hash: transaction_hash}
    end)
    |> InternalTransactionFetcher.async_fetch(10_000)

    tokens
    |> Enum.map(& &1.contract_address_hash)
    |> TokenFetcher.async_fetch()
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
  defp fetch_and_import_range_from_sequence(
         %__MODULE__{block_fetcher: %BlockFetcher{} = block_fetcher},
         _.._ = range,
         sequence
       ) do
    case fetch_and_import_range(block_fetcher, range) do
      {:ok, {inserted, next}} ->
        cap_seq(sequence, next, range)
        {:ok, inserted}

      {:error, {step, reason}} = error ->
        Logger.error(fn ->
          first..last = range
          "failed to fetch #{step} for blocks #{first} - #{last}: #{inspect(reason)}. Retrying block range."
        end)

        :ok = Sequence.queue(sequence, range)

        error

      {:error, changesets} = error when is_list(changesets) ->
        Logger.error(fn ->
          "failed to validate blocks #{inspect(range)}: #{inspect(changesets)}. Retrying"
        end)

        :ok = Sequence.queue(sequence, range)

        error

      {:error, {step, failed_value, _changes_so_far}} = error ->
        Logger.error(fn ->
          "failed to insert blocks during #{step} #{inspect(range)}: #{inspect(failed_value)}. Retrying"
        end)

        :ok = Sequence.queue(sequence, range)

        error
    end
  end

  defp cap_seq(seq, next, range) do
    case next do
      :more ->
        Logger.debug(fn ->
          first_block_number..last_block_number = range
          "got blocks #{first_block_number} - #{last_block_number}"
        end)

      :end_of_chain ->
        Sequence.cap(seq)
    end

    :ok
  end
end
