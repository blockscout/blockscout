defmodule BlockScoutWeb.AddressLogsController do
  @moduledoc """
  Manages events logs tab.
  """

  import BlockScoutWeb.Account.AuthController, only: [current_user: 1]

  import BlockScoutWeb.Chain, only: [paging_options: 1, next_page_params: 3, split_list_by_page: 1]

  import BlockScoutWeb.Models.GetAddressTags, only: [get_address_tags: 2]

  alias BlockScoutWeb.{AccessHelper, AddressLogsView, Controller}
  alias Explorer.{Chain, Market}
  alias Explorer.Chain.Address
  alias Explorer.Chain.SmartContract.Proxy.Models.Implementation
  alias Indexer.Fetcher.OnDemand.CoinBalance, as: CoinBalanceOnDemand
  alias Phoenix.View

  use BlockScoutWeb, :controller

  def index(conn, %{"address_id" => address_hash_string, "type" => "JSON"} = params) do
    with {:ok, address_hash} <- Chain.string_to_address_hash(address_hash_string),
         :ok <- Address.check_address_exists(address_hash),
         {:ok, false} <- AccessHelper.restricted_access?(address_hash_string, params) do
      options =
        params
        |> paging_options()
        |> Keyword.merge(
          necessity_by_association: %{
            [address: [:smart_contract, Implementation.proxy_implementations_smart_contracts_association()]] =>
              :optional
          }
        )

      logs_plus_one = Chain.address_to_logs(address_hash, false, options)
      {results, next_page} = split_list_by_page(logs_plus_one)

      next_page_url =
        case next_page_params(next_page, results, params) do
          nil ->
            nil

          next_page_params ->
            address_logs_path(conn, :index, address_hash, Map.delete(next_page_params, "type"))
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

  def index(conn, %{"address_id" => address_hash_string} = params) do
    ip = AccessHelper.conn_to_ip_string(conn)

    with {:ok, address_hash} <- Chain.string_to_address_hash(address_hash_string),
         {:ok, address} <- Chain.hash_to_address(address_hash),
         {:ok, false} <- AccessHelper.restricted_access?(address_hash_string, params) do
      render(
        conn,
        "index.html",
        address: address,
        current_path: Controller.current_full_path(conn),
        coin_balance_status: CoinBalanceOnDemand.trigger_fetch(ip, address),
        exchange_rate: Market.get_coin_exchange_rate(),
        counters_path: address_path(conn, :address_counters, %{"id" => address_hash_string}),
        tags: get_address_tags(address_hash, current_user(conn))
      )
    else
      _ ->
        not_found(conn)
    end
  end

  def search_logs(conn, %{"topic" => topic, "address_id" => address_hash_string} = params) do
    with {:ok, address_hash} <- Chain.string_to_address_hash(address_hash_string),
         :ok <- Address.check_address_exists(address_hash) do
      topic = String.trim(topic)

      formatted_topic = if String.starts_with?(topic, "0x"), do: topic, else: "0x" <> topic

      options =
        params
        |> paging_options()
        |> Keyword.merge(
          necessity_by_association: %{
            [address: [:smart_contract, Implementation.proxy_implementations_smart_contracts_association()]] =>
              :optional
          }
        )
        |> Keyword.merge(topic: formatted_topic)

      logs_plus_one = Chain.address_to_logs(address_hash, false, options)

      {results, next_page} = split_list_by_page(logs_plus_one)

      next_page_url =
        case next_page_params(next_page, results, params) do
          nil ->
            nil

          next_page_params ->
            address_logs_path(conn, :index, address_hash, Map.delete(next_page_params, "type"))
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

  def search_logs(conn, _), do: not_found(conn)
end
