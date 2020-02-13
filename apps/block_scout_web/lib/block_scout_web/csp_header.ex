defmodule BlockScoutWeb.CSPHeader do
  @moduledoc """
  Plug to set content-security-policy with websocket endpoints
  """

  alias Phoenix.Controller
  alias Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    Controller.put_secure_browser_headers(conn, %{
      "content-security-policy" => "\
        connect-src 'self' #{websocket_endpoints(conn)} #{Application.get_env(:block_scout_web, :provider_url)}; \
        default-src 'self';\
        script-src 'self' 'unsafe-inline' 'unsafe-eval' https://nico-amsterdam.github.io;\
        style-src 'self' 'unsafe-inline' 'unsafe-eval' https://fonts.googleapis.com https://nico-amsterdam.github.io;\
        img-src 'self' 'unsafe-inline' 'unsafe-eval' data:;\
        font-src 'self' 'unsafe-inline' 'unsafe-eval' https://fonts.gstatic.com data:;\
      "
    })
  end

  defp websocket_endpoints(conn) do
    host = Conn.get_req_header(conn, "host")
    "ws://#{host} wss://#{host}"
  end
end
