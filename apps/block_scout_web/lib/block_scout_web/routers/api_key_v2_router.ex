defmodule BlockScoutWeb.Routers.APIKeyV2Router do
  @moduledoc """
    Router for /api/v2/key. This route has separate router in order to avoid rate limiting
  """
  use BlockScoutWeb, :router
  alias BlockScoutWeb.Plug.{CheckApiV2, Logger}

  pipeline :api_v2 do
    plug(
      Plug.Parsers,
      parsers: [:urlencoded, :multipart, :json],
      length: 10_000,
      query_string_length: 5_000,
      pass: ["*/*"],
      json_decoder: Poison
    )

    plug(Logger, application: :api_v2)
    plug(:accepts, ["json"])
    plug(CheckApiV2)
  end

  scope "/", as: :api_v2 do
    pipe_through(:api_v2)

    alias BlockScoutWeb.API.V2

    post("/", V2.APIKeyController, :get_key)
  end
end
