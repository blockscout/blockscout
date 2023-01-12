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
        connect-src 'self' #{config[:mixpanel_url]} #{config[:amplitude_url]} #{websocket_endpoints(conn)} wss://*.bridge.walletconnect.org/ *.sentry.io *.google-analytics.com/ https://stats.g.doubleclick.net/ *.poa.network https://request-global.czilladx.com *.googlesyndication.com/ https://raw.githubusercontent.com/trustwallet/assets/ https://stats.g.doubleclick.net/ app.pendo.io pendo-io-static.storage.googleapis.com cdn.pendo.io pendo-static-6500107995185152.storage.googleapis.com data.pendo.io https://registry.walletconnect.org/data/wallets.json;\
        default-src 'self';\
        script-src 'self' 'unsafe-inline' 'unsafe-eval' *.googletagmanager.com *.google-analytics.com https://www.google.com https://www.gstatic.com *.hcaptcha.com https://coinzillatag.com *.googlesyndication.com https://adservice.google.com https://adservice.google.ru *.googletagservices.com *.googleadservices.com app.pendo.io pendo-io-static.storage.googleapis.com cdn.pendo.io pendo-static-6500107995185152.storage.googleapis.com data.pendo.io https://servedbyadbutler.com/app.js http://servedbyadbutler.com/adserve/;\
        style-src 'self' 'unsafe-inline' 'unsafe-eval' https://fonts.googleapis.com app.pendo.io cdn.pendo.io pendo-static-6500107995185152.storage.googleapis.com;\
        img-src 'self' * data: cdn.pendo.io app.pendo.io pendo-static-6500107995185152.storage.googleapis.com data.pendo.io;\
        media-src 'self' * data:;\
        font-src 'self' 'unsafe-inline' 'unsafe-eval' https://fonts.gstatic.com data:;\
        frame-ancestors app.pendo.io;\
        frame-src 'self' 'unsafe-inline' 'unsafe-eval' https://www.google.com *.hcaptcha.com https://request-global.czilladx.com/ https://googleads.g.doubleclick.net/ *.googlesyndication.com app.pendo.io http://servedbyadbutler.com/;\
        child-src app.pendo.io;\
      "
    })
  end

  defp websocket_endpoints(conn) do
    host = Conn.get_req_header(conn, "host")
    "ws://#{host} wss://#{host}"
  end
end
