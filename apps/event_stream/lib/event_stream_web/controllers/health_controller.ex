defmodule EventStream.HealthController do
  use EventStream, :controller

  alias EventStream.Publisher

  def ready(conn, _params) do
    conn
    |> put_status(200)
    |> json(%{status: "app initialized"})
  end

  def live(conn, _params) do
    live_publisher = Publisher.connected?()

    if live_publisher do
      conn
      |> put_status(200)
      |> json(%{status: "publisher connected"})
    else
      conn
      |> put_status(503)
      |> json(%{status: "publisher not connected"})
    end
  end
end
