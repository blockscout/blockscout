defmodule BlockScoutWeb.CSPHeader do
  @moduledoc """
  Plug to set content-security-policy with websocket endpoints
  """

  alias Phoenix.Controller
  alias Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    config = Application.get_env(:block_scout_web, __MODULE__)

    Controller.put_secure_browser_headers(conn, %{
      "content-security-policy" => "\
        connect-src 'self' #{config[:mixpanel_url]} #{config[:amplitude_url]} #{websocket_endpoints(conn)} wss://*.bridge.walletconnect.org/ https://request-global.czilladx.com/ https://raw.githubusercontent.com/trustwallet/assets/ https://registry.walletconnect.org/data/wallets.json https://*.poa.network https://*.google-analytics.com https://*.analytics.google.com https://*.googletagmanager.com;\
        default-src 'self';\
        script-src 'self' 'unsafe-inline' 'unsafe-eval' https://coinzillatag.com https://www.google.com https://www.gstatic.com https://www.googletagmanager.com https://*.googletagmanager.com ;\
        style-src 'self' 'unsafe-inline' 'unsafe-eval' https://fonts.googleapis.com;\
        img-src 'self' * data: https://*.google-analytics.com https://*.googletagmanager.com;\
        media-src 'self' * data:;\
        font-src 'self' 'unsafe-inline' 'unsafe-eval' https://fonts.gstatic.com data:;\
        frame-src 'self' 'unsafe-inline' 'unsafe-eval' https://request-global.czilladx.com/ https://www.google.com;\
      "
    })
  end

  defp websocket_endpoints(conn) do
    host = Conn.get_req_header(conn, "host")
    "ws://#{host} wss://#{host}"
  end
end
