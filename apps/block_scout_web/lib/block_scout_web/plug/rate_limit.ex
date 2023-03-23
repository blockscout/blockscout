defmodule BlockScoutWeb.Plug.RateLimit do
  @moduledoc """
    Rate limiting
  """
  alias BlockScoutWeb.AccessHelpers

  def init(opts), do: opts

  def call(conn, _opts) do
    with :ok <- AccessHelpers.check_rate_limit(conn) do
      conn
    else
      :rate_limit_reached ->
        AccessHelpers.handle_rate_limit_deny(conn, true)
    end
  end
end
