defmodule ExplorerWeb.AddressInternalTransactionController do
  @moduledoc """
    Manages the displaying of information about internal transactions as they relate to addresses
  """

  use ExplorerWeb, :controller

  import ExplorerWeb.AddressController, only: [transaction_count: 1]

  alias Explorer.{Chain, Market, PagingOptions}
  alias Explorer.ExchangeRates.Token

  @default_paging_options %PagingOptions{page_size: 50}

  def index(conn, %{"block_number" => block_number_string, "transaction_index" => transaction_index_string, "index" => index_string} = params) do
    with {block_number, ""} <- Integer.parse(block_number_string),
         {transaction_index, ""} <- Integer.parse(transaction_index_string),
         {index, ""} <- Integer.parse(index_string) do
      do_index(conn, Map.put(params, :paging_options, %{@default_paging_options | key: {block_number, transaction_index, index}}))
    else
      _ ->
        unprocessable_entity(conn)
    end
  end

  def index(conn, params), do: do_index(conn, params)

  def do_index(conn, %{"address_id" => address_hash_string} = params) do
    with {:ok, address_hash} <- Chain.string_to_address_hash(address_hash_string),
         {:ok, address} <- Chain.hash_to_address(address_hash) do
      full_options =
        Keyword.merge(
          [
            necessity_by_association: %{
              from_address: :optional,
              to_address: :optional
            },
            paging_options: @default_paging_options
          ],
          current_filter(params)
        )

      internal_transactions = Chain.address_to_internal_transactions(address, full_options)

      render(
        conn,
        "index.html",
        address: address,
        earliest: earliest(internal_transactions),
        exchange_rate: Market.get_exchange_rate(Explorer.coin()) || Token.null(),
        filter: params["filter"],
        internal_transactions: internal_transactions,
        transaction_count: transaction_count(address)
      )
    else
      :error ->
        not_found(conn)

      {:error, :not_found} ->
        not_found(conn)
    end
  end

  defp earliest([]), do: nil

  defp earliest(internal_transactions) do
    last = List.last(internal_transactions)
    {:ok, last_transaction} = Chain.hash_to_transaction(last.transaction_hash)
    %{block_number: last_transaction.block_number, transaction_index: last_transaction.index, index: last.index}
  end

  defp current_filter(%{paging_options: paging_options} = params) do
    params
    |> Map.get("filter")
    |> case do
      "to" -> [direction: :to, paging_options: paging_options]
      "from" -> [direction: :from, paging_options: paging_options]
      _ -> [paging_options: paging_options]
    end
  end

  defp current_filter(params) do
    params
    |> Map.get("filter")
    |> case do
      "to" -> [direction: :to]
      "from" -> [direction: :from]
      _ -> []
    end
  end
end
