defmodule BlockScoutWeb.Controller do
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
    |> put_view(BlockScoutWeb.PageNotFoundView)
    |> render(:index)
    |> halt()
  end

  def unprocessable_entity(conn) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(BlockScoutWeb.Error422View)
    |> render(:index)
    |> halt()
  end

  @doc """
  Checks if the request is AJAX or not.
  """
  def ajax?(conn) do
    case get_req_header(conn, "x-requested-with") do
      [value] -> value in ["XMLHttpRequest", "xmlhttprequest"]
      [] -> false
    end
  end
end
