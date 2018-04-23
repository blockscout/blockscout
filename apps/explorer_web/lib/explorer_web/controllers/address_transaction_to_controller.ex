defmodule ExplorerWeb.AddressTransactionToController do
  @moduledoc """
    Display all the Transactions that terminate at this Address.
  """

  use ExplorerWeb, :controller

  alias Explorer.Chain

  def index(conn, %{"address_id" => to_address_hash_string} = params) do
    with {:ok, to_address_hash} <- Chain.string_to_address_hash(to_address_hash_string),
         {:ok, to_address} <- Chain.hash_to_address(to_address_hash) do
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
    else
      :error ->
        not_found(conn)

      {:error, :not_found} ->
        not_found(conn)
    end
  end
end
