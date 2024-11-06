# This file in ignore list of `sobelow`, be careful while adding new endpoints here
defmodule BlockScoutWeb.Routers.APIv2ProxyAirTableRouter do
  @moduledoc """
    Router for /api/v2/proxy/airtable/ endpoints. This route has separate router in order to ignore sobelow's warning about missing CSRF protection
  """
  use BlockScoutWeb, :router
  alias BlockScoutWeb.API.V2
  alias BlockScoutWeb.Plug.{CheckApiV2, RateLimit}

  @max_query_string_length 5_000

  pipeline :api_v2 do
    plug(
      Plug.Parsers,
      parsers: [:urlencoded, :multipart, :json],
      query_string_length: @max_query_string_length,
      pass: ["*/*"],
      json_decoder: Poison
    )

    plug(BlockScoutWeb.Plug.Logger, application: :api_v2)
    plug(:accepts, ["json"])
    plug(CheckApiV2)
    plug(:fetch_session)
    plug(:protect_from_forgery)
    plug(RateLimit)
  end

  pipeline :api_v2_no_forgery_protect do
    plug(
      Plug.Parsers,
      parsers: [:urlencoded, :multipart, :json],
      length: 20_000_000,
      query_string_length: 5_000,
      pass: ["*/*"],
      json_decoder: Poison
    )

    plug(BlockScoutWeb.Plug.Logger, application: :api_v2)
    plug(:accepts, ["json"])
    plug(CheckApiV2)
    plug(RateLimit)
    plug(:fetch_session)
  end

  scope "/", as: :api_v2 do
    pipe_through(:api_v2_no_forgery_protect)

    patch("/:base_id/:table_id_or_name/:record_id", V2.Proxy.AirTableController, :patch)
    put("/:base_id/:table_id_or_name/:record_id", V2.Proxy.AirTableController, :put)
    post("/:base_id/:table_id_or_name", V2.Proxy.AirTableController, :post)
  end

  scope "/", as: :api_v2 do
    pipe_through(:api_v2)

    get("/:base_id/:table_id_or_name", V2.Proxy.AirTableController, :get_multiple)
    get("/:base_id/:table_id_or_name/:record_id", V2.Proxy.AirTableController, :get)
  end
end
