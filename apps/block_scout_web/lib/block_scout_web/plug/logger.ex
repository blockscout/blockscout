defmodule BlockScoutWeb.Plug.Logger do
  @moduledoc """
    Extended version of Plug.Logger from https://github.com/elixir-plug/plug/blob/v1.14.0/lib/plug/logger.ex
    Now it's possible to put parameters in order to log API v2 requests separately from API and others

    Usage example:
      `plug(BlockScoutWeb.Plug.Logger, application: :api_v2)`
  """

  require Logger
  alias Plug.Conn
  @behaviour Plug

  @impl true
  def init(opts) do
    opts
  end

  @impl true
  def call(conn, opts) do
    level = Keyword.get(opts, :log, :info)

    start = System.monotonic_time()

    Conn.register_before_send(conn, fn conn ->
      stop = System.monotonic_time()
      diff = System.convert_time_unit(stop - start, :native, :microsecond)
      status = Integer.to_string(conn.status)

      Logger.log(
        level,
        fn ->
          [connection_type(conn), ?\s, status, " in ", formatted_diff(diff), " on ", conn.method, ?\s, endpoint(conn)]
        end,
        Keyword.merge(
          [duration: diff, status: status, unit: "microsecond", endpoint: endpoint(conn), method: conn.method],
          opts
        )
      )

      conn
    end)
  end

  defp formatted_diff(diff) when diff > 1000, do: [diff |> div(1000) |> Integer.to_string(), "ms"]
  defp formatted_diff(diff), do: [Integer.to_string(diff), "µs"]

  defp connection_type(%{state: :set_chunked}), do: "Chunked"
  defp connection_type(_), do: "Sent"

  defp endpoint(conn) do
    if conn.query_string do
      "#{conn.request_path}?#{conn.query_string}"
    else
      conn.request_path
    end
  end
end
