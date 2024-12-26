defmodule BlockScoutWeb.HealthRouter do
  @moduledoc """
  Router for health checks in case of indexer-only setup
  """

  use BlockScoutWeb, :router

  alias BlockScoutWeb.API.HealthController

  scope "/api/health" do
    get("/", HealthController, :health)
    get("/liveness", HealthController, :liveness)
    get("/readiness", HealthController, :readiness)
  end
end
