defmodule Indexer.BlockFetcher.Realtime do
  @moduledoc """
  Fetches and indexes block ranges from latest block forward using a WebSocket.
  """

  use GenServer

  require Logger

  import EthereumJSONRPC, only: [integer_to_quantity: 1, quantity_to_integer: 1]
  import Indexer, only: [debug: 1]
  import Indexer.BlockFetcher, only: [fetch_and_import_range: 2]

  alias EthereumJSONRPC.Subscription
  alias Explorer.Chain
  alias Indexer.{AddressExtraction, BlockFetcher, TokenFetcher}

  @behaviour BlockFetcher

  @enforce_keys ~w(block_fetcher)a
  defstruct ~w(block_fetcher subscription)a

  @type t :: %__MODULE__{
          block_fetcher: %BlockFetcher{
            broadcast: true,
            callback_module: __MODULE__,
            json_rpc_named_arguments: EthereumJSONRPC.json_rpc_named_arguments(),
            receipts_batch_size: pos_integer(),
            receipts_concurrency: pos_integer()
          },
          subscription: Subscription.t()
        }

  def start_link([arguments, gen_server_options]) do
    GenServer.start_link(__MODULE__, arguments, gen_server_options)
  end

  @impl GenServer
  def init(%{block_fetcher: %BlockFetcher{} = block_fetcher, subscribe_named_arguments: subscribe_named_arguments})
      when is_list(subscribe_named_arguments) do
    {:ok, %__MODULE__{block_fetcher: %BlockFetcher{block_fetcher | broadcast: true, callback_module: __MODULE__}},
     {:continue, {:init, subscribe_named_arguments}}}
  end

  @impl GenServer
  def handle_continue({:init, subscribe_named_arguments}, %__MODULE__{subscription: nil} = state)
      when is_list(subscribe_named_arguments) do
    case EthereumJSONRPC.subscribe("newHeads", subscribe_named_arguments) do
      {:ok, subscription} -> {:noreply, %__MODULE__{state | subscription: subscription}}
      {:error, reason} -> {:stop, reason, state}
    end
  end

  @impl GenServer
  def handle_info(
        {subscription, {:ok, %{"number" => quantity}}},
        %__MODULE__{
          block_fetcher: %BlockFetcher{} = block_fetcher,
          subscription: %Subscription{} = subscription
        } = state
      )
      when is_binary(quantity) do
    number = quantity_to_integer(quantity)

    # Subscriptions don't support getting all the blocks and transactions data, so we need to go back and get the full block
    case fetch_and_import_range(block_fetcher, number..number) do
      {:ok, {_inserted, _next}} ->
        debug(fn ->
          ["realtime indexer fetched and imported block ", to_string(number)]
        end)

      {:error, {step, reason}} ->
        Logger.error(fn ->
          [
            "realtime indexer failed to fetch ",
            to_string(step),
            " for block ",
            to_string(number),
            ": ",
            inspect(reason),
            ".  Block will be retried by catchup indexer."
          ]
        end)

      {:error, changesets} when is_list(changesets) ->
        Logger.error(fn ->
          [
            "realtime indexer failed to validate for block ",
            to_string(number),
            ": ",
            inspect(changesets),
            ".  Block will be retried by catchup indexer."
          ]
        end)

      {:error, {step, failed_value, _changes_so_far}} ->
        Logger.error(fn ->
          [
            "realtime indexer failed to insert ",
            to_string(step),
            " for block ",
            to_string(number),
            ": ",
            inspect(failed_value),
            ".  Block will be retried by catchup indexer."
          ]
        end)
    end

    {:noreply, state}
  end

  @import_options ~w(address_hash_to_fetched_balance_block_number transaction_hash_to_block_number)a

  @impl BlockFetcher
  def import(
        block_fetcher,
        %{
          address_hash_to_fetched_balance_block_number: address_hash_to_block_number,
          balances: %{params: balance_params},
          addresses: %{params: addresses_params},
          transactions: %{params: transactions_params}
        } = options
      ) do
    with {:ok,
          %{
            addresses_params: internal_transactions_addresses_params,
            internal_transactions_params: internal_transactions_params
          }} <-
           internal_transactions(block_fetcher, %{
             addresses_params: addresses_params,
             transactions_params: transactions_params
           }),
         {:ok, %{addresses_params: balances_addresses_params, balances_params: balances_params}} <-
           balances(block_fetcher, %{
             address_hash_to_block_number: address_hash_to_block_number,
             addresses_params: internal_transactions_addresses_params,
             balances_params: balance_params
           }),
         chain_import_options =
           options
           |> Map.drop(@import_options)
           |> put_in([:addresses, :params], balances_addresses_params)
           |> put_in([Access.key(:balances, %{}), :params], balances_params)
           |> put_in([Access.key(:internal_transactions, %{}), :params], internal_transactions_params),
         {:ok, results} = ok <- Chain.import(chain_import_options) do
      async_import_remaining_block_data(results)
      ok
    end
  end

  defp async_import_remaining_block_data(%{tokens: tokens}) do
    tokens
    |> Enum.map(& &1.contract_address_hash)
    |> TokenFetcher.async_fetch()
  end

  defp internal_transactions(
         %BlockFetcher{json_rpc_named_arguments: json_rpc_named_arguments},
         %{addresses_params: addresses_params, transactions_params: transactions_params}
       ) do
    case transactions_params
         |> transactions_params_to_fetch_internal_transactions_params()
         |> EthereumJSONRPC.fetch_internal_transactions(json_rpc_named_arguments) do
      {:ok, internal_transactions_params} ->
        merged_addresses_params =
          %{internal_transactions: internal_transactions_params}
          |> AddressExtraction.extract_addresses()
          |> Kernel.++(addresses_params)
          |> AddressExtraction.merge_addresses()

        {:ok, %{addresses_params: merged_addresses_params, internal_transactions_params: internal_transactions_params}}

      :ignore ->
        {:ok, %{addresses_params: addresses_params, internal_transactions_params: []}}

      {:error, _reason} = error ->
        error
    end
  end

  defp transactions_params_to_fetch_internal_transactions_params(transactions_params) do
    Enum.map(transactions_params, &transaction_params_to_fetch_internal_transaction_params/1)
  end

  defp transaction_params_to_fetch_internal_transaction_params(%{block_number: block_number, hash: hash})
       when is_integer(block_number) do
    %{block_number: block_number, hash_data: to_string(hash)}
  end

  defp balances(
         %BlockFetcher{json_rpc_named_arguments: json_rpc_named_arguments},
         %{addresses_params: addresses_params} = options
       ) do
    with {:ok, fetched_balances_params} <-
           options
           |> fetch_balances_params_list()
           |> EthereumJSONRPC.fetch_balances(json_rpc_named_arguments) do
      merged_addresses_params =
        %{balances: fetched_balances_params}
        |> AddressExtraction.extract_addresses()
        |> Kernel.++(addresses_params)
        |> AddressExtraction.merge_addresses()

      value_fetched_at = DateTime.utc_now()
      importable_balances_params = Enum.map(fetched_balances_params, &Map.put(&1, :value_fetched_at, value_fetched_at))

      {:ok, %{addresses_params: merged_addresses_params, balances_params: importable_balances_params}}
    end
  end

  defp fetch_balances_params_list(%{
         addresses_params: addresses_params,
         address_hash_to_block_number: address_hash_to_block_number,
         balances_params: balances_params
       }) do
    addresses_params
    |> addresses_params_to_fetched_balances_params_set(%{address_hash_to_block_number: address_hash_to_block_number})
    |> MapSet.union(balances_params_to_fetch_balances_params_set(balances_params))
    # stable order for easier moxing
    |> Enum.sort_by(fn %{hash_data: hash_data, block_quantity: block_quantity} -> {hash_data, block_quantity} end)
  end

  defp addresses_params_to_fetched_balances_params_set(addresses_params, %{
         address_hash_to_block_number: address_hash_to_block_number
       }) do
    Enum.into(addresses_params, MapSet.new(), fn %{hash: address_hash} = address_params when is_binary(address_hash) ->
      block_number =
        case address_params do
          %{fetched_balance_block_number: block_number} when is_integer(block_number) ->
            block_number

          _ ->
            Map.fetch!(address_hash_to_block_number, address_hash)
        end

      %{hash_data: address_hash, block_quantity: integer_to_quantity(block_number)}
    end)
  end

  defp balances_params_to_fetch_balances_params_set(balances_params) do
    Enum.into(balances_params, MapSet.new(), fn %{address_hash: address_hash, block_number: block_number} ->
      %{hash_data: address_hash, block_quantity: integer_to_quantity(block_number)}
    end)
  end
end
