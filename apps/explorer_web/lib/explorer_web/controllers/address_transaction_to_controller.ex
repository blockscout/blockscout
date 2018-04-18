defmodule ExplorerWeb.AddressTransactionToController do
  @moduledoc """
    Display all the Transactions that terminate at this Address.
  """

  use ExplorerWeb, :controller

  alias Explorer.Chain

  def index(conn, %{"address_id" => to_address_hash} = params) do
    case Chain.hash_to_address(to_address_hash) do
      {:ok, to_address} ->
        page =
          Chain.to_address_to_transactions(
            to_address,
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
