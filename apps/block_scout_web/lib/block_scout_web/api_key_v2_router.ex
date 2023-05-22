defmodule BlockScoutWeb.APIKeyV2Router do
  @moduledoc """
    Router for /api/v2/key. This route has separate router in order to avoid rate limiting
  """
  use BlockScoutWeb, :router
  alias BlockScoutWeb.Plug.{CheckApiV2, Logger}

  pipeline :api_v2 do
    plug(Logger, application: :api_v2)
    plug(:accepts, ["json"])
    plug(CheckApiV2)
    plug(:fetch_session)
    plug(:protect_from_forgery)
  end

  scope "/", as: :api_v2 do
    pipe_through(:api_v2)

    alias BlockScoutWeb.API.V2

    get("/", V2.APIKeyController, :get_key)
  end
end
