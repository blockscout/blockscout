defmodule BlockScoutWeb.Plug.CheckAuth do
  @moduledoc """
    Checks if the guardian did find token. If not, send 401 Unauthorized response
  """
  import Plug.Conn

  alias Guardian.Plug

  def init(opts), do: opts

  def call(conn, _opts) do
    if is_nil(Plug.current_claims(conn)) do
      conn
      |> put_resp_content_type("application/json")
      |> send_resp(401, Jason.encode!(%{message: "Unauthorized"}))
      |> halt()
    else
      conn
    end
  end
end
