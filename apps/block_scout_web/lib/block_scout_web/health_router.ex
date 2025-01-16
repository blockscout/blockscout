defmodule BlockScoutWeb.HealthRouter do
  @moduledoc """
  Router for health checks in case of indexer-only setup
  """

  use BlockScoutWeb, :router

  scope "/api/health" do
    get("/", BlockScoutWeb.API.V1.HealthController, :health)
    get("/liveness", BlockScoutWeb.API.V1.HealthController, :liveness)
    get("/readiness", BlockScoutWeb.API.V1.HealthController, :readiness)
  end
end
