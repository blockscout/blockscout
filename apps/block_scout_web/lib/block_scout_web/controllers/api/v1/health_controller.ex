defmodule BlockScoutWeb.API.V1.HealthController do
  use BlockScoutWeb, :controller

  alias Explorer.Chain

  def last_block_status(conn, _) do
    # Chain.last_block_status()
  end
end
