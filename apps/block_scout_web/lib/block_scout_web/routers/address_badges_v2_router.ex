# This file in ignore list of `sobelow`, be careful while adding new endpoints here
defmodule BlockScoutWeb.Routers.AddressBadgesApiV2Router do
  @moduledoc """
    Router for /api/v2/address-badges. This route has separate router in order to ignore sobelow's warning about missing CSRF protection
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

    post("/", V2.AddressBadgeController, :create_badge)
    post("/:badge_id/addresses/add", V2.AddressBadgeController, :add_addresses_to_badge)
    post("/:badge_id/addresses/remove", V2.AddressBadgeController, :remove_addresses_to_badge)
    patch("/:badge_id", V2.AddressBadgeController, :update_badge)
    delete("/:badge_id", V2.AddressBadgeController, :delete_badge)
  end

  scope "/", as: :api_v2 do
    pipe_through(:api_v2)

    get("/:badge_id", V2.AddressBadgeController, :badge)
    get("/:badge_id/addresses/show", V2.AddressBadgeController, :show_badge_addresses)
  end
end
