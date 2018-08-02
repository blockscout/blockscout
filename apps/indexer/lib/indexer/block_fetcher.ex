defmodule Indexer.BlockFetcher do
  @moduledoc """
  Fetches and indexes block ranges.
  """

  require Logger

  import Indexer, only: [debug: 1]

  alias Explorer.Chain.{Block, Import}
  alias Indexer.{AddressExtraction, Sequence}
  alias Indexer.BlockFetcher.Receipts

  # dialyzer thinks that Logger.debug functions always have no_local_return
  @dialyzer {:nowarn_function, import_range: 2}

  # These are all the *default* values for options.
  # DO NOT use them directly in the code.  Get options from `state`.

  @blocks_batch_size 10
  @blocks_concurrency 10

  @receipts_batch_size 250
  @receipts_concurrency 10

  @type address_hash_to_fetched_balance_block_number :: %{String.t() => Block.block_number()}
  @type transaction_hash_to_block_number :: %{String.t() => Block.block_number()}

  @type t :: %__MODULE__{}

  @doc """
  Calculates the balances and internal transactions and imports those with the given data.
  """
  @callback import(
              t,
              %{
                address_hash_to_fetched_balance_block_number: address_hash_to_fetched_balance_block_number,
                transaction_hash_to_block_number_option: transaction_hash_to_block_number,
                addresses: Import.addresses_options(),
                blocks: Import.blocks_options(),
                broadcast: boolean,
                logs: Import.logs_options(),
                receipts: Import.receipts_options(),
                transactions: Import.transactions_options()
              }
            ) :: Import.all_result()

  @enforce_keys ~w(json_rpc_named_arguments)a
  defstruct blocks_batch_size: @blocks_batch_size,
            blocks_concurrency: @blocks_concurrency,
            broadcast: nil,
            callback_module: nil,
            json_rpc_named_arguments: nil,
            receipts_batch_size: @receipts_batch_size,
            receipts_concurrency: @receipts_concurrency,
            sequence: nil

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
      connections.
    * `:receipts_batch_size` - The number of receipts to request in one call to the JSONRPC.  Defaults to
      `#{@receipts_batch_size}`.  Receipt requests also include the logs for when the transaction was collated into the
      block.  *These logs are not paginated.*
    * `:receipts_concurrency` - The number of concurrent requests of `:receipts_batch_size` to allow against the JSONRPC
      **for each block range**. Defaults to `#{@receipts_concurrency}`.  So upto
      `block_concurrency * receipts_batch_size * receipts_concurrency` (defaults to
      `#{@blocks_concurrency * @receipts_concurrency * @receipts_batch_size}`) receipts can be requested from the
      JSONRPC at once over all connections. *Each transaction only has one receipt.*
  """
  def new(named_arguments) when is_list(named_arguments) do
    struct!(__MODULE__, named_arguments)
  end

  def stream_import(%__MODULE__{blocks_concurrency: blocks_concurrency, sequence: sequence} = state)
      when is_pid(sequence) do
    sequence
    |> Sequence.build_stream()
    |> Task.async_stream(
      &import_range(state, &1),
      max_concurrency: blocks_concurrency,
      timeout: :infinity
    )
    |> Stream.run()
  end

  defp cap_seq(seq, next, range) do
    case next do
      :more ->
        debug(fn ->
          first_block_number..last_block_number = range
          "got blocks #{first_block_number} - #{last_block_number}"
        end)

      :end_of_chain ->
        Sequence.cap(seq)
    end

    :ok
  end

  defp insert(%__MODULE__{broadcast: broadcast, callback_module: callback_module, sequence: sequence} = state, options)
       when is_map(options) do
    {address_hash_to_fetched_balance_block_number, import_options} =
      pop_address_hash_to_fetched_balance_block_number(options)

    transaction_hash_to_block_number = get_transaction_hash_to_block_number(import_options)

    options_with_broadcast =
      Map.merge(
        import_options,
        %{
          address_hash_to_fetched_balance_block_number: address_hash_to_fetched_balance_block_number,
          broadcast: broadcast,
          transaction_hash_to_block_number: transaction_hash_to_block_number
        }
      )

    # use a `case` to ensure that `callback_module` `import` has correct return type
    case callback_module.import(state, options_with_broadcast) do
      {:ok, _} = ok ->
        ok

      {:error, step, failed_value, _changes_so_far} = error ->
        %{range: range} = options

        debug(fn ->
          "failed to insert blocks during #{step} #{inspect(range)}: #{inspect(failed_value)}. Retrying"
        end)

        :ok = Sequence.queue(sequence, range)

        error
    end
  end

  # `fetched_balance_block_number` is needed for the `BalanceFetcher`, but should not be used for `import` because the
  # balance is not known yet.
  defp pop_address_hash_to_fetched_balance_block_number(options) do
    {address_hash_fetched_balance_block_number_pairs, import_options} =
      get_and_update_in(options, [:addresses, :params, Access.all()], &pop_hash_fetched_balance_block_number/1)

    address_hash_to_fetched_balance_block_number = Map.new(address_hash_fetched_balance_block_number_pairs)
    {address_hash_to_fetched_balance_block_number, import_options}
  end

  defp get_transaction_hash_to_block_number(options) do
    options
    |> get_in([:transactions, :params, Access.all()])
    |> Enum.into(%{}, fn %{block_number: block_number, hash: hash} ->
      {hash, block_number}
    end)
  end

  defp pop_hash_fetched_balance_block_number(
         %{
           fetched_balance_block_number: fetched_balance_block_number,
           hash: hash
         } = address_params
       ) do
    {{hash, fetched_balance_block_number}, Map.delete(address_params, :fetched_balance_block_number)}
  end

  # Run at state.blocks_concurrency max_concurrency when called by `stream_import/1`
  # Only public for testing
  @doc false
  def import_range(%__MODULE__{json_rpc_named_arguments: json_rpc_named_arguments, sequence: seq} = state, range) do
    with {:blocks, {:ok, next, result}} <-
           {:blocks, EthereumJSONRPC.fetch_blocks_by_range(range, json_rpc_named_arguments)},
         %{blocks: blocks, transactions: transactions_without_receipts} = result,
         cap_seq(seq, next, range),
         {:receipts, {:ok, receipt_params}} <- {:receipts, Receipts.fetch(state, transactions_without_receipts)},
         %{logs: logs, receipts: receipts} = receipt_params,
         transactions_with_receipts = Receipts.put(transactions_without_receipts, receipts) do
      addresses =
        AddressExtraction.extract_addresses(%{
          blocks: blocks,
          logs: logs,
          transactions: transactions_with_receipts
        })

      insert(
        state,
        %{
          range: range,
          addresses: %{params: addresses},
          blocks: %{params: blocks},
          logs: %{params: logs},
          receipts: %{params: receipts},
          transactions: %{params: transactions_with_receipts, on_conflict: :replace_all}
        }
      )
    else
      {step, {:error, reason}} ->
        debug(fn ->
          first..last = range
          "failed to fetch #{step} for blocks #{first} - #{last}: #{inspect(reason)}. Retrying block range."
        end)

        :ok = Sequence.queue(seq, range)

        {:error, step, reason}
    end
  end
end
