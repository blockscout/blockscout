defmodule BlockScoutWeb.AddressTransactionController do
  @moduledoc """
    Display all the Transactions that terminate at this Address.
  """

  use BlockScoutWeb, :controller

  import BlockScoutWeb.AddressController, only: [transaction_count: 1, validation_count: 1]
  import BlockScoutWeb.Chain, only: [current_filter: 1, paging_options: 1, next_page_params: 3, split_list_by_page: 1]

  alias BlockScoutWeb.TransactionView
  alias Explorer.{Chain, Market}
  alias Explorer.ExchangeRates.Token
  alias Indexer.Fetcher.CoinBalanceOnDemand
  alias Phoenix.View

  @transaction_necessity_by_association [
    necessity_by_association: %{
      [created_contract_address: :names] => :optional,
      [from_address: :names] => :optional,
      [to_address: :names] => :optional,
      [token_transfers: :token] => :optional,
      [token_transfers: :to_address] => :optional,
      [token_transfers: :from_address] => :optional,
      [token_transfers: :token_contract_address] => :optional
    }
  ]

  def index(conn, %{"address_id" => address_hash_string, "type" => "JSON"} = params) do
    with {:ok, address_hash} <- Chain.string_to_address_hash(address_hash_string),
         {:ok, address} <- Chain.hash_to_address(address_hash) do
      options =
        @transaction_necessity_by_association
        |> put_in([:necessity_by_association, :block], :required)
        |> Keyword.merge(paging_options(params))
        |> Keyword.merge(current_filter(params))

      results_plus_one = Chain.address_to_transactions_with_rewards(address, options)
      {results, next_page} = split_list_by_page(results_plus_one)

      next_page_url =
        case next_page_params(next_page, results, params) do
          nil ->
            nil

          next_page_params ->
            address_transaction_path(
              conn,
              :index,
              address,
              Map.delete(next_page_params, "type")
            )
        end

      items_json =
        Enum.map(results, fn result ->
          case result do
            {%Chain.Block.Reward{} = emission_reward, %Chain.Block.Reward{} = validator_reward} ->
              View.render_to_string(
                TransactionView,
                "_emission_reward_tile.html",
                current_address: address,
                emission_funds: emission_reward,
                validator: validator_reward
              )

            %Chain.Transaction{} = transaction ->
              View.render_to_string(
                TransactionView,
                "_tile.html",
                current_address: address,
                transaction: transaction
              )
          end
        end)

      json(conn, %{items: items_json, next_page_path: next_page_url})
    else
      :error ->
        unprocessable_entity(conn)

      {:error, :not_found} ->
        not_found(conn)
    end
  end

  def index(conn, %{"address_id" => address_hash_string} = params) do
    with {:ok, address_hash} <- Chain.string_to_address_hash(address_hash_string),
         {:ok, address} <- Chain.hash_to_address(address_hash) do
      render(
        conn,
        "index.html",
        address: address,
        coin_balance_status: CoinBalanceOnDemand.trigger_fetch(address),
        exchange_rate: Market.get_exchange_rate(Explorer.coin()) || Token.null(),
        filter: params["filter"],
        transaction_count: transaction_count(address),
        validation_count: validation_count(address),
        current_path: current_path(conn)
      )
    else
      :error ->
        unprocessable_entity(conn)

      {:error, :not_found} ->
        not_found(conn)
    end
  end
end
