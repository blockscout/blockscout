defmodule ExplorerWeb.AddressInternalTransactionController do
  @moduledoc """
    Manages the displaying of information about internal transactions as they relate to addresses
  """

  use ExplorerWeb, :controller

  import ExplorerWeb.AddressController, only: [coin: 0, transaction_count: 1]

  alias Explorer.{Chain, Market}
  alias Explorer.ExchangeRates.Token

  def index(conn, %{"address_id" => address_hash_string} = params) do
    with {:ok, address_hash} <- Chain.string_to_address_hash(address_hash_string),
         {:ok, address} <- Chain.hash_to_address(address_hash) do
      options = [
        necessity_by_association: %{
          from_address: :optional,
          to_address: :optional
        },
        pagination: params
      ]

      page =
        Chain.address_to_internal_transactions(
          address,
          Keyword.merge(options, current_filter(params))
        )

      render(
        conn,
        "index.html",
        address: address,
        exchange_rate: Market.get_exchange_rate(coin()) || Token.null(),
        filter: params["filter"],
        page: page,
        transaction_count: transaction_count(address)
      )
    else
      :error ->
        not_found(conn)

      {:error, :not_found} ->
        not_found(conn)
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
