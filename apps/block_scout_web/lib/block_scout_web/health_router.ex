defmodule BlockScoutWeb.HealthRouter do
  @moduledoc """
  Router for health checks in case of indexer-only setup
  """

  use BlockScoutWeb, :router

  scope "/api/health" do
    get("/", BlockScoutWeb.API.HealthController, :health)
    get("/liveness", BlockScoutWeb.API.HealthController, :liveness)
    get("/readiness", BlockScoutWeb.API.HealthController, :readiness)
  end
end
