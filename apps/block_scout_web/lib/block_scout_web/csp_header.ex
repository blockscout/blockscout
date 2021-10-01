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
        connect-src 'self' #{websocket_endpoints(conn)} *.sentry.io *.google-analytics.com https://stats.g.doubleclick.net/ *.poa.network/ https://request-global.czilladx.com/ *.googlesyndication.com/ https://raw.githubusercontent.com/trustwallet/assets/; \
        default-src 'self';\
        script-src 'self' 'unsafe-inline' 'unsafe-eval' *.googletagmanager.com *.google-analytics.com https://www.google.com https://www.gstatic.com https://hcaptcha.com https://assets.hcaptcha.com https://newassets.hcaptcha.com https://coinzillatag.com *.googlesyndication.com https://adservice.google.com https://adservice.google.ru *.googletagservices.com *.googleadservices.com; \
        style-src 'self' 'unsafe-inline' 'unsafe-eval' https://fonts.googleapis.com;\
        img-src 'self' * data:;\
        media-src 'self' * data:;\
        font-src 'self' 'unsafe-inline' 'unsafe-eval' https://fonts.gstatic.com data:;\
        frame-src 'self' 'unsafe-inline' 'unsafe-eval' https://www.google.com https://hcaptcha.com https://assets.hcaptcha.com https://newassets.hcaptcha.com https://request-global.czilladx.com/ https://googleads.g.doubleclick.net/ *.googlesyndication.com;\
      "
    })
  end

  defp websocket_endpoints(conn) do
    host = Conn.get_req_header(conn, "host")
    "ws://#{host} wss://#{host}"
  end
end
