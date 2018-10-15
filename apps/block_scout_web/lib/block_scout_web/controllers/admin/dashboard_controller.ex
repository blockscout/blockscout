defmodule BlockScoutWeb.Admin.DashboardController do
  use BlockScoutWeb, :controller

  def index(conn, _) do
    render(conn, "index.html")
  end
end
