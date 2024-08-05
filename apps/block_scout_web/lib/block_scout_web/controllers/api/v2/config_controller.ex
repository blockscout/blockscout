defmodule BlockScoutWeb.API.V2.ConfigController do
  use BlockScoutWeb, :controller

  def backend_version(conn, _params) do
    backend_version = Application.get_env(:block_scout_web, :version)

    conn
    |> put_status(200)
    |> render(:backend_version, %{version: backend_version})
  end

  def csv_export(conn, _params) do
    limit = Application.get_env(:explorer, :csv_export_limit)

    conn
    |> put_status(200)
    |> json(%{limit: limit})
  end
end
