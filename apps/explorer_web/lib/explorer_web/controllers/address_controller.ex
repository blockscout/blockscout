defmodule ExplorerWeb.AddressController do
  use ExplorerWeb, :controller

  alias Explorer.Chain

  def show(conn, %{"id" => hash} = params) do
    case Chain.hash_to_address(hash) do
      {:ok, address} ->
        page = transactions_for_address(address, params)
        render(conn, "show.html", address: address, page: page)

      {:error, :not_found} ->
        not_found(conn)
    end
  end

  defp transactions_for_address(address, params) do
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
  end
end
