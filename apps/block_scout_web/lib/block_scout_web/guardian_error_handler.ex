defmodule BlockScoutWeb.GuardianErrorHandler do
  import Plug.Conn

  @behaviour Guardian.Plug.ErrorHandler

  @impl Guardian.Plug.ErrorHandler
  def auth_error(conn, {type, _reason}, opts) do
    if Keyword.get(opts, :tolerant?) do
      conn
    else
      body = Jason.encode!(%{message: to_string(type)})

      conn
      |> put_resp_content_type("application/json")
      |> send_resp(401, body)
      |> halt()
    end
  end
end
