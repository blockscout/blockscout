defmodule BlockScoutWeb.Plug.CheckAccountAPI do
  @moduledoc """
    Checks if the Account functionality enabled for API level.
  """
  import Plug.Conn

  alias Explorer.Account

  def init(opts), do: opts

  def call(conn, _opts) do
    if Account.enabled?() do
      conn
    else
      conn
      |> put_resp_content_type("application/json")
      |> send_resp(404, Jason.encode!(%{message: "Account functionality is disabled"}))
      |> halt()
    end
  end
end
