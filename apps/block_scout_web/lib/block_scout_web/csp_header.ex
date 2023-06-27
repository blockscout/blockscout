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
        connect-src 'self' 'unsafe-inline' 'unsafe-eval' 'unsafe-hashes' #{websocket_endpoints(conn)} wss://*.bridge.walletconnect.org/ https://raw.githubusercontent.com/trustwallet/assets/ https://registry.walletconnect.org/data/wallets.json https://*.google-analytics.com https://*.analytics.google.com https://*.googletagmanager.com;\
        default-src 'self'; \
        script-src 'self' 'unsafe-inline' 'unsafe-eval' 'unsafe-hashes' https://www.google.com https://www.gstatic.com https://www.googletagmanager.com;\
        style-src 'self' 'unsafe-inline' 'unsafe-eval' https://fonts.googleapis.com; \
        img-src 'self' * data: https://*.google-analytics.com https://*.googletagmanager.com;\
        media-src 'self' * data:;\
        font-src 'self' 'unsafe-inline' 'unsafe-eval' https://fonts.gstatic.com data:;\
        frame-src 'self' 'unsafe-inline' 'unsafe-eval' https://www.google.com https://datastudio.google.com/ https://lookerstudio.google.com/ https://makerdojo.io/;\
      "
    })
  end

  defp websocket_endpoints(conn) do
    host = Conn.get_req_header(conn, "host")
    "ws://#{host} wss://#{host}"
  end
end
