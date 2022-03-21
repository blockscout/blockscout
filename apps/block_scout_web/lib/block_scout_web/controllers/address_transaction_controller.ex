defmodule BlockScoutWeb.AddressTransactionController do
  @moduledoc """
    Display all the Transactions that terminate at this Address.
  """

  use BlockScoutWeb, :controller

  import BlockScoutWeb.Chain,
    only: [
      current_filter: 1,
      next_page_params: 2,
      supplement_page_options: 2
    ]

  alias BlockScoutWeb.{AccessHelpers, Controller, TransactionView}
  alias Explorer.{Chain, Market, PagingOptions}

  alias Explorer.Chain.{
    AddressInternalTransactionCsvExporter,
    AddressLogCsvExporter,
    AddressTokenTransferCsvExporter,
    AddressTransactionCsvExporter
  }

  alias Explorer.ExchangeRates.Token
  alias Indexer.Fetcher.CoinBalanceOnDemand
  alias Phoenix.View

  @default_options [
    paging_options: %PagingOptions{page_size: Chain.default_page_size()},
    necessity_by_association: %{
      [created_contract_address: :names] => :optional,
      [from_address: :names] => :optional,
      [to_address: :names] => :optional,
      [created_contract_address: :smart_contract] => :optional,
      [from_address: :smart_contract] => :optional,
      [to_address: :smart_contract] => :optional
    }
  ]

  {:ok, burn_address_hash} = Chain.string_to_address_hash("0x0000000000000000000000000000000000000000")
  @burn_address_hash burn_address_hash

  def index(conn, %{"address_id" => address_hash_string, "type" => "JSON"} = params) do
    address_options = [necessity_by_association: %{:names => :optional, :smart_contract => :optional}]

    with {:ok, address_hash} <- Chain.string_to_address_hash(address_hash_string),
         {:ok, address} <- Chain.hash_to_address(address_hash, address_options, false),
         {:ok, false} <- AccessHelpers.restricted_access?(address_hash_string, params) do
      options =
        @default_options
        |> Keyword.merge(current_filter(params))
        |> supplement_page_options(params)

      %{transactions_count: transactions_count, transactions: transactions} =
        Chain.address_to_transactions_rap(address_hash, options)

      next_page_params = next_page_params(params, transactions_count)

      items_json =
        Enum.map(transactions, fn transaction ->
          View.render_to_string(
            TransactionView,
            "_tile.html",
            conn: conn,
            current_address: address,
            transaction: transaction,
            burn_address_hash: @burn_address_hash
          )
        end)

      json(conn, %{items: items_json, next_page_params: next_page_params})
    else
      :error ->
        unprocessable_entity(conn)

      {:restricted_access, _} ->
        not_found(conn)

      {:error, :not_found} ->
        case Chain.Hash.Address.validate(address_hash_string) do
          {:ok, _} ->
            json(conn, %{items: [], next_page_params: nil})

          _ ->
            not_found(conn)
        end
    end
  end

  def index(conn, %{"address_id" => address_hash_string} = params) do
    with {:ok, address_hash} <- Chain.string_to_address_hash(address_hash_string),
         {:ok, address} <- Chain.hash_to_address(address_hash),
         {:ok, false} <- AccessHelpers.restricted_access?(address_hash_string, params) do
      render(
        conn,
        "index.html",
        address: address,
        coin_balance_status: CoinBalanceOnDemand.trigger_fetch(address),
        exchange_rate: Market.get_exchange_rate(Explorer.coin()) || Token.null(),
        filter: params["filter"],
        counters_path: address_path(conn, :address_counters, %{"id" => address_hash_string}),
        current_path: Controller.current_full_path(conn)
      )
    else
      :error ->
        unprocessable_entity(conn)

      {:restricted_access, _} ->
        not_found(conn)

      {:error, :not_found} ->
        {:ok, address_hash} = Chain.string_to_address_hash(address_hash_string)
        address = %Chain.Address{hash: address_hash, smart_contract: nil, token: nil}

        case Chain.Hash.Address.validate(address_hash_string) do
          {:ok, _} ->
            render(
              conn,
              "index.html",
              address: address,
              coin_balance_status: nil,
              exchange_rate: Market.get_exchange_rate(Explorer.coin()) || Token.null(),
              filter: params["filter"],
              counters_path: address_path(conn, :address_counters, %{"id" => address_hash_string}),
              current_path: Controller.current_full_path(conn)
            )

          _ ->
            not_found(conn)
        end
    end
  end

  def token_transfers_csv(conn, %{
        "address_id" => address_hash_string,
        "from_period" => from_period,
        "to_period" => to_period
      })
      when is_binary(address_hash_string) do
    with {:ok, address_hash} <- Chain.string_to_address_hash(address_hash_string),
         {:ok, address} <- Chain.hash_to_address(address_hash) do
      address
      |> AddressTokenTransferCsvExporter.export(from_period, to_period)
      |> Enum.into(
        conn
        |> put_resp_content_type("application/csv")
        |> put_resp_header("content-disposition", "attachment; filename=token_transfers.csv")
        |> send_chunked(200)
      )
    else
      :error ->
        unprocessable_entity(conn)

      {:error, :not_found} ->
        not_found(conn)
    end
  end

  def token_transfers_csv(conn, _), do: not_found(conn)

  def transactions_csv(conn, %{
        "address_id" => address_hash_string,
        "from_period" => from_period,
        "to_period" => to_period
      }) do
    with {:ok, address_hash} <- Chain.string_to_address_hash(address_hash_string),
         {:ok, address} <- Chain.hash_to_address(address_hash) do
      address
      |> AddressTransactionCsvExporter.export(from_period, to_period)
      |> Enum.into(
        conn
        |> put_resp_content_type("application/csv")
        |> put_resp_header("content-disposition", "attachment; filename=transactions.csv")
        |> send_chunked(200)
      )
    else
      :error ->
        unprocessable_entity(conn)

      {:error, :not_found} ->
        not_found(conn)
    end
  end

  def transactions_csv(conn, _), do: not_found(conn)

  def internal_transactions_csv(conn, %{
        "address_id" => address_hash_string,
        "from_period" => from_period,
        "to_period" => to_period
      }) do
    with {:ok, address_hash} <- Chain.string_to_address_hash(address_hash_string),
         {:ok, address} <- Chain.hash_to_address(address_hash) do
      address
      |> AddressInternalTransactionCsvExporter.export(from_period, to_period)
      |> Enum.into(
        conn
        |> put_resp_content_type("application/csv")
        |> put_resp_header("content-disposition", "attachment; filename=internal_transactions.csv")
        |> send_chunked(200)
      )
    else
      :error ->
        unprocessable_entity(conn)

      {:error, :not_found} ->
        not_found(conn)
    end
  end

  def internal_transactions_csv(conn, _), do: not_found(conn)

  def logs_csv(conn, %{"address_id" => address_hash_string, "from_period" => from_period, "to_period" => to_period}) do
    with {:ok, address_hash} <- Chain.string_to_address_hash(address_hash_string),
         {:ok, address} <- Chain.hash_to_address(address_hash) do
      address
      |> AddressLogCsvExporter.export(from_period, to_period)
      |> Enum.into(
        conn
        |> put_resp_content_type("application/csv")
        |> put_resp_header("content-disposition", "attachment; filename=logs.csv")
        |> send_chunked(200)
      )
    else
      :error ->
        unprocessable_entity(conn)

      {:error, :not_found} ->
        not_found(conn)
    end
  end

  def logs_csv(conn, _), do: not_found(conn)
end
