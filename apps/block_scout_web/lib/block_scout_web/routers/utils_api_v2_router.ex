# This file in ignore list of `sobelow`, be careful while adding new endpoints here
defmodule BlockScoutWeb.Routers.UtilsApiV2Router do
  @moduledoc """
    Router for /api/v2/utils. This route has separate router in order to ignore sobelow's warning about missing CSRF protection
  """
  use BlockScoutWeb, :router
  alias BlockScoutWeb.Plug.CheckApiV2

  pipeline :api_v2_no_forgery_protect do
    plug(
      Plug.Parsers,
      parsers: [:urlencoded, :multipart, :json],
      length: 100_000,
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
    alias BlockScoutWeb.API.V2

    get("/decode-calldata", V2.UtilsController, :decode_calldata)
    post("/decode-calldata", V2.UtilsController, :decode_calldata)
  end
end
