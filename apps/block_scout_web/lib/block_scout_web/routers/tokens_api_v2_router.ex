# This file in ignore list of `sobelow`, be careful while adding new endpoints here
defmodule BlockScoutWeb.Routers.TokensApiV2Router do
  @moduledoc """
    Router for /api/v2/tokens. This route has separate router in order to ignore sobelow's warning about missing CSRF protection
  """
  use BlockScoutWeb, :router
  use Utils.CompileTimeEnvHelper, bridged_tokens_enabled: [:explorer, [Explorer.Chain.BridgedToken, :enabled]]

  alias BlockScoutWeb.API.V2
  alias BlockScoutWeb.Plug.CheckApiV2

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
    plug(:fetch_session)
  end

  scope "/", as: :api_v2 do
    pipe_through(:api_v2_no_forgery_protect)

    patch("/:address_hash_param/instances/:token_id/refetch-metadata", V2.TokenController, :refetch_metadata)

    patch(
      "/:address_hash_param/instances/refetch-metadata",
      V2.TokenController,
      :trigger_nft_collection_metadata_refetch
    )
  end

  scope "/", as: :api_v2 do
    pipe_through(:api_v2)

    if @bridged_tokens_enabled do
      get("/bridged", V2.TokenController, :bridged_tokens_list)
    end

    get("/", V2.TokenController, :tokens_list)
    get("/:address_hash_param", V2.TokenController, :token)
    get("/:address_hash_param/counters", V2.TokenController, :counters)
    get("/:address_hash_param/transfers", V2.TokenController, :transfers)
    get("/:address_hash_param/holders", V2.TokenController, :holders)
    get("/:address_hash_param/holders/csv", V2.CsvExportController, :export_token_holders)
    get("/:address_hash_param/instances", V2.TokenController, :instances)
    get("/:address_hash_param/instances/:token_id", V2.TokenController, :instance)
    get("/:address_hash_param/instances/:token_id/transfers", V2.TokenController, :transfers_by_instance)
    get("/:address_hash_param/instances/:token_id/holders", V2.TokenController, :holders_by_instance)
    get("/:address_hash_param/instances/:token_id/transfers-count", V2.TokenController, :transfers_count_by_instance)
  end
end
