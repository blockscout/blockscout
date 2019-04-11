defmodule BlockScoutWeb.StatsController do
    use BlockScoutWeb, :controller
    alias Phoenix.View
    alias Explorer.Stats

    def index(conn, _params) do
        render(
            conn,
            "index.html",
            current_path: current_path(conn),
        )
    end

end