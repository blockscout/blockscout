defmodule Indexer.Block.Fetcher do
  @moduledoc """
  Fetches and indexes block ranges.
  """

  require Logger

  alias Explorer.Chain.{Block, Import}
  alias Indexer.{CoinBalance, AddressExtraction, Token, TokenTransfers}
  alias Indexer.Address.{CoinBalances, TokenBalances}
  alias Indexer.Block.Fetcher.Receipts

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
                addresses: Import.Runner.options(),
                address_coin_balances: Import.Runner.options(),
                address_token_balances: Import.Runner.options(),
                blocks: Import.Runner.options(),
                block_second_degree_relations: Import.Runner.options(),
                broadcast: boolean,
                logs: Import.Runner.options(),
                token_transfers: Import.Runner.options(),
                tokens: Import.Runner.options(),
                transactions: Import.Runner.options()
              }
            ) :: Import.all_result()

  # These are all the *default* values for options.
  # DO NOT use them directly in the code.  Get options from `state`.

  @receipts_batch_size 250
  @receipts_concurrency 10

  @doc false
  def default_receipts_batch_size, do: @receipts_batch_size

  @doc false
  def default_receipts_concurrency, do: @receipts_concurrency

  @enforce_keys ~w(json_rpc_named_arguments)a
  defstruct broadcast: nil,
            callback_module: nil,
            json_rpc_named_arguments: nil,
            receipts_batch_size: @receipts_batch_size,
            receipts_concurrency: @receipts_concurrency

  @doc """
  Required named arguments

    * `:json_rpc_named_arguments` - `t:EthereumJSONRPC.json_rpc_named_arguments/0` passed to
        `EthereumJSONRPC.json_rpc/2`.

  The follow options can be overridden:

    * `:receipts_batch_size` - The number of receipts to request in one call to the JSONRPC.  Defaults to
      `#{@receipts_batch_size}`.  Receipt requests also include the logs for when the transaction was collated into the
      block.  *These logs are not paginated.*
    * `:receipts_concurrency` - The number of concurrent requests of `:receipts_batch_size` to allow against the JSONRPC
      **for each block range**.  Defaults to `#{@receipts_concurrency}`.  *Each transaction only has one receipt.*

  """
  def new(named_arguments) when is_map(named_arguments) do
    struct!(__MODULE__, named_arguments)
  end

  @spec fetch_and_import_range(t, Range.t()) ::
          {:ok, {inserted :: %{}, next :: :more | :end_of_chain}}
          | {:error,
             {step :: atom(), reason :: term()}
             | [%Ecto.Changeset{}]
             | {step :: atom(), failed_value :: term(), changes_so_far :: term()}}
  def fetch_and_import_range(
        %__MODULE__{
          broadcast: broadcast,
          callback_module: callback_module,
          json_rpc_named_arguments: json_rpc_named_arguments
        } = state,
        _.._ = range
      )
      when broadcast in ~w(true false)a and callback_module != nil do
    with {:blocks, {:ok, next, result}} <-
           {:blocks, EthereumJSONRPC.fetch_blocks_by_range(range, json_rpc_named_arguments)},
         %{
           blocks: blocks,
           transactions: transactions_without_receipts,
           block_second_degree_relations: block_second_degree_relations
         } = result,
         {:receipts, {:ok, receipt_params}} <- {:receipts, Receipts.fetch(state, transactions_without_receipts)},
         %{logs: logs, receipts: receipts} = receipt_params,
         transactions_with_receipts = Receipts.put(transactions_without_receipts, receipts),
         %{token_transfers: token_transfers, tokens: tokens} = TokenTransfers.parse(logs),
         addresses =
           AddressExtraction.extract_addresses(%{
             blocks: blocks,
             logs: logs,
             token_transfers: token_transfers,
             transactions: transactions_with_receipts
           }),
         coin_balances_params_set =
           CoinBalances.params_set(%{
             blocks_params: blocks,
             logs_params: logs,
             transactions_params: transactions_with_receipts
           }),
         address_token_balances = TokenBalances.params_set(%{token_transfers_params: token_transfers}),
         {:ok, inserted} <-
           __MODULE__.import(
             state,
             %{
               addresses: %{params: addresses},
               address_coin_balances: %{params: coin_balances_params_set},
               address_token_balances: %{params: address_token_balances},
               blocks: %{params: blocks},
               block_second_degree_relations: %{params: block_second_degree_relations},
               logs: %{params: logs},
               token_transfers: %{params: token_transfers},
               tokens: %{on_conflict: :nothing, params: tokens},
               transactions: %{params: transactions_with_receipts, on_conflict: :replace_all}
             }
           ) do
      {:ok, {inserted, next}}
    else
      {step, {:error, reason}} -> {:error, {step, reason}}
      {:error, changesets} = error when is_list(changesets) -> error
      {:error, step, failed_value, changes_so_far} -> {:error, {step, failed_value, changes_so_far}}
    end
  end

  def import(
        %__MODULE__{broadcast: broadcast, callback_module: callback_module} = state,
        options
      )
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

    callback_module.import(state, options_with_broadcast)
  end

  def async_import_coin_balances(%{addresses: addresses}, %{
        address_hash_to_fetched_balance_block_number: address_hash_to_block_number
      }) do
    addresses
    |> Enum.map(fn address_hash ->
      block_number = Map.fetch!(address_hash_to_block_number, to_string(address_hash))
      %{address_hash: address_hash, block_number: block_number}
    end)
    |> CoinBalance.Fetcher.async_fetch_balances()
  end

  def async_import_coin_balances(_, _), do: :ok

  def async_import_tokens(%{tokens: tokens}) do
    tokens
    |> Enum.map(& &1.contract_address_hash)
    |> Token.Fetcher.async_fetch()
  end

  def async_import_tokens(_), do: :ok

  def async_import_uncles(%{block_second_degree_relations: block_second_degree_relations}) do
    block_second_degree_relations
    |> Enum.map(& &1.uncle_hash)
    |> Indexer.Block.Uncle.Fetcher.async_fetch_blocks()
  end

  def async_import_uncles(_), do: :ok

  # `fetched_balance_block_number` is needed for the `CoinBalanceFetcher`, but should not be used for `import` because the
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
           fetched_coin_balance_block_number: fetched_coin_balance_block_number,
           hash: hash
         } = address_params
       ) do
    {{hash, fetched_coin_balance_block_number}, Map.delete(address_params, :fetched_coin_balance_block_number)}
  end
end
