defmodule ExplorerWeb.CSPHeader do
  @moduledoc """
  Plug to set content-security-policy with websocket endpoints
  """

  alias Phoenix.Controller

  def init(opts), do: opts

  def call(conn, _opts) do
    Controller.put_secure_browser_headers(conn, %{
      "content-security-policy" => "\
        connect-src 'self' #{websocket_endpoints(conn)}; \
        default-src 'self';\
        script-src 'self' 'unsafe-inline' 'unsafe-eval';\
        style-src 'self' 'unsafe-inline' 'unsafe-eval' https://fonts.googleapis.com;\
        img-src 'self' 'unsafe-inline' 'unsafe-eval' data:;\
        font-src 'self' 'unsafe-inline' 'unsafe-eval' https://fonts.gstatic.com data:;\
      "
    })
  end

  defp websocket_endpoints(conn) do
    endpoint = Controller.endpoint_module(conn)
    ws_endpoint = %{endpoint.struct_url | scheme: "ws"} |> URI.to_string()
    wss_endpoint = %{endpoint.struct_url | scheme: "wss"} |> URI.to_string()
    "#{ws_endpoint} #{wss_endpoint}"
  end
end
