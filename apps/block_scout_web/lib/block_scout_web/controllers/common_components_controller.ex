defmodule BlockScoutWeb.CommonComponentsController do
  use BlockScoutWeb, :controller

  alias BlockScoutWeb.CommonComponentsView

  def index(conn, params) do
    []
    |> handle_render(conn, params)
  end

  defp handle_render(full_options, conn, _params) do
    render(conn, "index.html")
  end
end
