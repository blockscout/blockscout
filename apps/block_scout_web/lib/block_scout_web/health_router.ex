defmodule BlockScoutWeb.HealthRouter do
  use BlockScoutWeb, :router

  alias BlockScoutWeb.API.V1.HealthController

  @max_query_string_length 5_000

  pipeline :api do
    plug(
      Plug.Parsers,
      parsers: [:urlencoded, :multipart, :json],
      length: 20_000_000,
      query_string_length: @max_query_string_length,
      pass: ["*/*"],
      json_decoder: Poison
    )

    plug(BlockScoutWeb.Plug.Logger, application: :api)
    plug(:accepts, ["json"])
  end

  scope "/api" do
    scope "/v1", as: :api_v1 do
      scope "/health" do
        get("/", HealthController, :health)
        get("/liveness", HealthController, :liveness)
        get("/readiness", HealthController, :readiness)
      end
    end
  end
end
