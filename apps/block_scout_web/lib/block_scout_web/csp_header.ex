defmodule BlockScoutWeb.CSPHeader do
  @moduledoc """
  Plug to set content-security-policy with websocket endpoints
  """

  alias Phoenix.Controller
  alias Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    config = Application.get_env(:block_scout_web, __MODULE__)
    google_url = "https://www.google.com"
    czilladx_url = "https://request-global.czilladx.com"
    coinzillatag_url = "https://coinzillatag.com"
    trustwallet_url = "https://raw.githubusercontent.com/trustwallet/assets/"
    walletconnect_urls = "wss://*.bridge.walletconnect.org https://registry.walletconnect.org/data/wallets.json"
    pendo_app_url = "app.pendo.io"
    pendo_cdn_url = "cdn.pendo.io"
    pendo_data_url = "data.pendo.io"
    pendo_io_static_url = "pendo-io-static.storage.googleapis.com"
    pendo_static_url = "pendo-static-6500107995185152.storage.googleapis.com"
    google_syndication_url = "*.googlesyndication.com"
    json_rpc_url = Application.get_env(:block_scout_web, :json_rpc)

    Controller.put_secure_browser_headers(conn, %{
      "content-security-policy" => "\
        connect-src 'self' #{json_rpc_url} #{config[:mixpanel_url]} #{config[:amplitude_url]} #{websocket_endpoints(conn)} #{walletconnect_urls} *.sentry.io *.google-analytics.com/ *.poa.network #{czilladx_url} #{google_syndication_url} #{trustwallet_url} https://stats.g.doubleclick.net/ #{pendo_app_url} #{pendo_io_static_url} #{pendo_cdn_url} #{pendo_static_url} #{pendo_data_url};\
        default-src 'self';\
        script-src 'self' 'unsafe-inline' 'unsafe-eval' *.googletagmanager.com *.google-analytics.com #{google_url} https://www.gstatic.com *.hcaptcha.com #{coinzillatag_url} #{google_syndication_url} https://adservice.google.com https://adservice.google.ru *.googletagservices.com *.googleadservices.com #{pendo_app_url} #{pendo_io_static_url} #{pendo_cdn_url} #{pendo_static_url} #{pendo_data_url} https://servedbyadbutler.com/app.js http://servedbyadbutler.com/adserve/;\
        style-src 'self' 'unsafe-inline' 'unsafe-eval' https://fonts.googleapis.com #{pendo_app_url} #{pendo_cdn_url} #{pendo_static_url};\
        img-src 'self' * data: #{pendo_cdn_url} #{pendo_app_url} #{pendo_static_url} #{pendo_data_url};\
        media-src 'self' * data:;\
        font-src 'self' 'unsafe-inline' 'unsafe-eval' https://fonts.gstatic.com data:;\
        frame-ancestors #{pendo_app_url};\
        frame-src 'self' 'unsafe-inline' 'unsafe-eval' #{google_url} *.hcaptcha.com #{czilladx_url} https://googleads.g.doubleclick.net/ #{google_syndication_url} #{pendo_app_url} http://servedbyadbutler.com/;\
        child-src #{pendo_app_url};\
      "
    })
  end

  defp websocket_endpoints(conn) do
    host = Conn.get_req_header(conn, "host")
    "ws://#{host} wss://#{host}"
  end
end
