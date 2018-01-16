defmodule ExplorerWeb.PageController do
  use ExplorerWeb, :controller

  def index(conn, _params) do
    render conn, "index.html"
  end
end
