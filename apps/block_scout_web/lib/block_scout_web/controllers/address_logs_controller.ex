defmodule BlockScoutWeb.AddressLogsController do
  @moduledoc """
  Manages events logs tab.
  """

  import BlockScoutWeb.AddressController, only: [transaction_count: 1, validation_count: 1]
  import BlockScoutWeb.Chain, only: [paging_options: 1, next_page_params: 3, split_list_by_page: 1]

  alias BlockScoutWeb.AddressLogsView
  alias Explorer.{Chain, Market}
  alias Explorer.ExchangeRates.Token
  alias Indexer.Fetcher.CoinBalanceOnDemand
  alias Phoenix.View

  use BlockScoutWeb, :controller

  def index(conn, %{"address_id" => address_hash_string, "type" => "JSON"} = params) do
    with {:ok, address_hash} <- Chain.string_to_address_hash(address_hash_string),
         {:ok, address} <- Chain.hash_to_address(address_hash) do
      logs_plus_one = Chain.address_to_logs(address, paging_options(params))
      {results, next_page} = split_list_by_page(logs_plus_one)

      next_page_url =
        case next_page_params(next_page, results, params) do
          nil ->
            nil

          next_page_params ->
            address_logs_path(conn, :index, address, Map.delete(next_page_params, "type"))
        end

      items =
        results
        |> Enum.map(fn log ->
          View.render_to_string(
            AddressLogsView,
            "_logs.html",
            log: log,
            conn: conn
          )
        end)

      json(
        conn,
        %{
          items: items,
          next_page_path: next_page_url
        }
      )
    else
      _ ->
        not_found(conn)
    end
  end

  def index(conn, %{"address_id" => address_hash_string}) do
    with {:ok, address_hash} <- Chain.string_to_address_hash(address_hash_string),
         {:ok, address} <- Chain.hash_to_address(address_hash) do
      render(
        conn,
        "index.html",
        address: address,
        current_path: current_path(conn),
        coin_balance_status: CoinBalanceOnDemand.trigger_fetch(address),
        exchange_rate: Market.get_exchange_rate(Explorer.coin()) || Token.null(),
        transaction_count: transaction_count(address),
        validation_count: validation_count(address)
      )
    else
      _ ->
        not_found(conn)
    end
  end

  def search_logs(conn, %{"topic" => topic, "address_id" => address_hash_string} = params) do
    with {:ok, address_hash} <- Chain.string_to_address_hash(address_hash_string),
         {:ok, address} <- Chain.hash_to_address(address_hash) do
      topic = String.trim(topic)
      logs_plus_one = Chain.address_to_logs(address, topic: topic)

      {results, next_page} = split_list_by_page(logs_plus_one)

      next_page_url =
        case next_page_params(next_page, results, params) do
          nil ->
            nil

          next_page_params ->
            address_logs_path(conn, :index, address, Map.delete(next_page_params, "type"))
        end

      items =
        results
        |> Enum.map(fn log ->
          View.render_to_string(
            AddressLogsView,
            "_logs.html",
            log: log,
            conn: conn
          )
        end)

      json(
        conn,
        %{
          items: items,
          next_page_path: next_page_url
        }
      )
    else
      _ ->
        not_found(conn)
    end
  end
end
