defmodule ExplorerWeb.AddressController do
  use ExplorerWeb, :controller

  alias Explorer.Chain
  alias Explorer.Chain.Address

  def show(conn, %{"id" => id, "locale" => locale}) do
    redirect(conn, to: address_transaction_path(conn, :index, locale, id))
  end

  def transaction_count(%Address{} = address) do
    Chain.address_to_transaction_count(address)
  end
end
