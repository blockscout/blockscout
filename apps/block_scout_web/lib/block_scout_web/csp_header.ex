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
        connect-src 'self' #{websocket_endpoints(conn)} wss://*.bridge.walletconnect.org/ https://request-global.czilladx.com/ https://raw.githubusercontent.com/trustwallet/assets/ https://registry.walletconnect.org/data/wallets.json https://*.poa.network;\
        default-src 'self';\
        script-src 'self' 'sha256-bA0SJeg1gTpu+3isk3u6dVrrwpPIjqHTlaOZf3Rbks0=' 'sha256-QADITpnBuiXVfTzrfwP9VzAxptWL1j2UNMPM72SNEno=' 'sha256-N3zDxQhzCysUhiADVoOWSdfhBGDHYwpDuxsnYQ+HMps=' 'sha256-4A+kQlK4FlWSfsaRQIupw354UQEb928PY226YQHYP2o=' sha256-QADITpnBuiXVfTzrfwP9VzAxptWL1j2UNMPM72SNEno=' 'sha256-S+kA9ZZC2ANiKZW1Soge1NhdxH9M4c2UTARyyzpLBio=' 'sha256-fqGNTzWau5hfYKKH3B59dBNOSh8VdaIQ5YXzH+9C0Ys=' 'sha256-89/1LLiXXHmqi3EdeHqEQ7Kz1VVc+6OXCUaen1kiUfg=' 'sha256-IBxcGAt2latSKF1Je/SHpNwTeU5Q1WKiBVNd13xlAiA=' *.google.com *.gstatic.com;\
        style-src 'self' 'unsafe-inline' fonts.googleapis.com;\
        img-src 'self' * data:;\
        media-src 'self' * data:;\
        font-src 'self' 'unsafe-inline' fonts.gstatic.com data:;\
        frame-src 'self' 'unsafe-inline' *.google.com;\
      "
    })
  end

  defp websocket_endpoints(conn) do
    host = Conn.get_req_header(conn, "host")
    "ws://#{host} wss://#{host}"
  end
end
