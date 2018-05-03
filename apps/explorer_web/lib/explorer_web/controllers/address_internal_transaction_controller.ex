defmodule ExplorerWeb.AddressInternalTransactionController do
  @moduledoc """
    Manages the displaying of information about internal transactions as they relate to addresses
  """

  use ExplorerWeb, :controller

  alias Explorer.Chain

  def index(conn, %{"address_id" => address_hash} = params) do
    case Chain.hash_to_address(address_hash) do
      {:ok, address} ->
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

        render(conn, "index.html", address: address, filter: params["filter"], page: page)

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
