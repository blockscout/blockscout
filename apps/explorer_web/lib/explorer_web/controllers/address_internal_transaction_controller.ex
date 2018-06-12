defmodule ExplorerWeb.AddressInternalTransactionController do
  @moduledoc """
    Manages the displaying of information about internal transactions as they relate to addresses
  """

  use ExplorerWeb, :controller

  import ExplorerWeb.AddressController, only: [transaction_count: 1]

  alias Explorer.{Chain, Market, PagingOptions}
  alias Explorer.ExchangeRates.Token

  @page_size 50
  @default_paging_options %PagingOptions{page_size: @page_size + 1}

  def index(conn, %{"address_id" => address_hash_string} = params) do
    with {:ok, address_hash} <- Chain.string_to_address_hash(address_hash_string),
         {:ok, address} <- Chain.hash_to_address(address_hash) do
      full_options =
        [
          necessity_by_association: %{
            from_address: :optional,
            to_address: :optional
          }
        ]
        |> Keyword.merge(paging_options(params))
        |> Keyword.merge(current_filter(params))

      internal_transactions_plus_one = Chain.address_to_internal_transactions(address, full_options)

      {next_page, internal_transactions} = List.pop_at(internal_transactions_plus_one, @page_size)

      render(
        conn,
        "index.html",
        address: address,
        next_page_params: next_page_params(next_page, internal_transactions),
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

  defp next_page_params(nil, _transactions), do: nil

  defp next_page_params(_, internal_transactions) do
    last = List.last(internal_transactions)
    {:ok, last_transaction} = Chain.hash_to_transaction(last.transaction_hash)
    %{block_number: last_transaction.block_number, transaction_index: last_transaction.index, index: last.index}
  end

  defp paging_options(params) do
    with %{
           "block_number" => block_number_string,
           "transaction_index" => transaction_index_string,
           "index" => index_string
         } <- params,
         {block_number, ""} <- Integer.parse(block_number_string),
         {transaction_index, ""} <- Integer.parse(transaction_index_string),
         {index, ""} <- Integer.parse(index_string) do
      [paging_options: %{@default_paging_options | key: {block_number, transaction_index, index}}]
    else
      _ ->
        [paging_options: @default_paging_options]
    end
  end
end
