defmodule BlockScoutWeb.AddressController do
  use BlockScoutWeb, :controller

  alias Explorer.Chain
  alias Explorer.Chain.Address

  def show(conn, %{"id" => id}) do
    redirect(conn, to: address_transaction_path(conn, :index, id))
  end

  def transaction_count(%Address{} = address) do
    Chain.address_to_transaction_count_estimate(address)
  end
end
