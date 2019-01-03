defmodule BlockScoutWeb.Plug.AllowIframe do
  @moduledoc """
  Allows for iframes by deleting the
  [`X-Frame-Options` header](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/X-Frame-Options)
  """

  alias Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    Conn.delete_resp_header(conn, "x-frame-options")
  end
end
