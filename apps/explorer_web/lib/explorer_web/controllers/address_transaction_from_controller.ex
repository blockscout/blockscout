defmodule ExplorerWeb.AddressTransactionFromController do
  @moduledoc """
    Display all the Transactions that originate at this Address.
  """

  use ExplorerWeb, :controller

  alias Explorer.Chain

  def index(conn, %{"address_id" => from_address_hash_string} = params) do
    with {:ok, from_address_hash} <- Chain.string_to_address_hash(from_address_hash_string),
         {:ok, from_address} <- Chain.hash_to_address(from_address_hash) do
      page =
        Chain.from_address_to_transactions(
          from_address,
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
