defmodule BlockScoutWeb.Plug.CheckApiV2 do
  @moduledoc """
    Checks if the API V2 enabled.
  """
  import Plug.Conn

  alias BlockScoutWeb.API.V2, as: API_V2

  def init(opts), do: opts

  def call(conn, _opts) do
    if API_V2.enabled?() do
      conn
    else
      conn
      |> put_resp_content_type("application/json")
      |> send_resp(404, Jason.encode!(%{message: "API V2 is disabled"}))
      |> halt()
    end
  end
end
