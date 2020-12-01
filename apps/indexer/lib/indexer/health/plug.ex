defmodule Indexer.Health.Plug do
  @moduledoc """
  Plug that exposes health checks as web endpoints.
  """

  import Plug.Conn
  alias Explorer.Health

  @behaviour Plug

  @path_readiness "/health/readiness"
  @path_liveness "/health/liveness"

  # Plug Callbacks
  @impl true
  def init(opts), do: opts

  @impl true
  def call(%Plug.Conn{} = conn, _opts) do
    case conn.request_path do
      @path_liveness -> health_response(conn, Health.alive?())
      @path_readiness -> health_response(conn, Health.ready?())
      _other -> not_found_response(conn)
    end
  end

  defp not_found_response(conn) do
    conn
    |> send_resp(404, "Not Found")
    |> halt()
  end

  defp health_response(conn, true) do
    conn
    |> send_resp(200, "OK")
    |> halt()
  end

  defp health_response(conn, false) do
    conn
    |> send_resp(503, "Service Unavailable")
    |> halt()
  end
end
