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

  def public_metrics(conn, _params) do
    public_metrics_update_period_hours = Application.get_env(:explorer, Explorer.Chain.Metrics)[:update_period_hours]

    conn
    |> put_status(200)
    |> json(%{update_period_hours: public_metrics_update_period_hours})
  end

  def celo(conn, _params) do
    config = Application.get_env(:explorer, :celo)

    conn
    |> put_status(200)
    |> json(%{l2_migration_block: config[:l2_migration_block]})
  end
end
