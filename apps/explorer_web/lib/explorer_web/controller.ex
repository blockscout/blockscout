defmodule ExplorerWeb.Controller do
  @moduledoc """
  Common controller error responses
  """

  import Phoenix.Controller
  import Plug.Conn

  @doc """
  Renders HTML Not Found error
  """
  def not_found(conn) do
    conn
    |> put_status(:not_found)
    |> put_view(ExplorerWeb.ErrorView)
    |> render("404.html")
  end
end
