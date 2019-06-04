defmodule BlockScoutWeb.CommonComponentsController do
  use BlockScoutWeb, :controller

  def index(conn, params) do
    []
    |> handle_render(conn, params)
  end

  defp handle_render(_full_options, conn, _params) do
    render(conn, "index.html")
  end
end
