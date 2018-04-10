defmodule ExplorerWeb.AddressTransactionController do
  @moduledoc """
    Display all the Transactions that terminate at this Address.
  """

  use ExplorerWeb, :controller

  alias Explorer.Chain

  def index(conn, %{"address_id" => to_address_hash} = params) do
    case Chain.hash_to_address(to_address_hash) do
      {:ok, address} ->
        page =
          Chain.address_to_transactions(
            address,
            direction: :to,
            necessity_by_association: %{
              block: :required,
              from_address: :optional,
              to_address: :optional,
              receipt: :required
            },
            pagination: params
          )

        render(conn, "index.html", page: page)

      {:error, :not_found} ->
        not_found(conn)
    end
  end
end
