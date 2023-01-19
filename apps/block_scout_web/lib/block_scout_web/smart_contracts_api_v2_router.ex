# This file in ignore list of `sobelow`, be careful while adding new endpoints here
defmodule BlockScoutWeb.SmartContractsApiV2Router do
  @moduledoc """
    Router for /api/v2/smart-contracts. This route has separate router in order to ignore solelow's warning about missing CSRF protection
  """
  use BlockScoutWeb, :router
  alias BlockScoutWeb.Plug.CheckApiV2

  pipeline :api do
    plug(:accepts, ["json"])
  end

  pipeline :api_v2_no_forgery_protect do
    plug(CheckApiV2)
    plug(:fetch_session)
  end

  scope "/", as: :api_v2 do
    pipe_through(:api)
    pipe_through(:api_v2_no_forgery_protect)

    alias BlockScoutWeb.API.V2

    get("/:address_hash", V2.SmartContractController, :smart_contract)
    get("/:address_hash/methods-read", V2.SmartContractController, :methods_read)
    get("/:address_hash/methods-write", V2.SmartContractController, :methods_write)
    get("/:address_hash/methods-read-proxy", V2.SmartContractController, :methods_read_proxy)
    get("/:address_hash/methods-write-proxy", V2.SmartContractController, :methods_write_proxy)
    post("/:address_hash/query-read-method", V2.SmartContractController, :query_read_method)

    get("/verification/config", V2.VerificationController, :config)

    scope "/:address_hash/verification/via" do
      post("/flattened-code", V2.VerificationController, :verification_via_flattened_code)
      post("/standard-input", V2.VerificationController, :verification_via_standard_input)
      post("/sourcify", V2.VerificationController, :verification_via_sourcify)
      post("/multi-part", V2.VerificationController, :verification_via_multi_part)
      post("/vyper-code", V2.VerificationController, :verification_via_vyper_code)
    end
  end
end
