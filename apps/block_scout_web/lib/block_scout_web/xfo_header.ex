defmodule BlockScoutWeb.XFOHeader do
  @moduledoc """
  Plug to set x-frame-options with websocket endpoints
  """

  alias Phoenix.Controller

  def init(opts), do: opts

  def call(conn, _opts) do
    Controller.put_secure_browser_headers(conn, %{
      "X-Frame-Options" => "SAMEORIGIN"
    })
  end
end
