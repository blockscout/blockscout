defmodule ExplorerWeb.AddressController do
  use ExplorerWeb, :controller

  def show(conn, %{"id" => id, "locale" => locale}) do
    redirect(conn, to: address_transaction_path(conn, :index, locale, id))
  end
end
