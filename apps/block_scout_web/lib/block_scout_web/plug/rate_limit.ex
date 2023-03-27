defmodule BlockScoutWeb.Plug.RateLimit do
  @moduledoc """
    Rate limiting
  """
  alias BlockScoutWeb.AccessHelper

  def init(opts), do: opts

  def call(conn, _opts) do
    with :ok <- AccessHelper.check_rate_limit(conn) do
      conn
    else
      :rate_limit_reached ->
        AccessHelper.handle_rate_limit_deny(conn, true)
    end
  end
end
