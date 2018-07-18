defmodule ExplorerWeb.TokenController do
  use ExplorerWeb, :controller

  def show(conn, %{"id" => id, "locale" => locale}) do
    render(
      conn,
      "show.html"
    )
  end
end
