# This file in ignore list of `sobelow`, be careful while adding new endpoints here
defmodule BlockScoutWeb.Routers.SmartContractsApiV2Router do
  @moduledoc """
    Router for /api/v2/smart-contracts. This route has separate router in order to ignore sobelow's warning about missing CSRF protection
  """
  use BlockScoutWeb, :router
  use Utils.CompileTimeEnvHelper, chain_type: [:explorer, :chain_type]

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
    pipe_through(:api_v2)

    get("/", V2.SmartContractController, :smart_contracts_list)
    get("/counters", V2.SmartContractController, :smart_contracts_counters)
    get("/:address_hash", V2.SmartContractController, :smart_contract)
    get("/:address_hash/methods-read", V2.SmartContractController, :methods_read)
    get("/:address_hash/methods-write", V2.SmartContractController, :methods_write)
    get("/:address_hash/methods-read-proxy", V2.SmartContractController, :methods_read_proxy)
    get("/:address_hash/methods-write-proxy", V2.SmartContractController, :methods_write_proxy)
    get("/:address_hash/solidityscan-report", V2.SmartContractController, :solidityscan_report)
    get("/:address_hash/audit-reports", V2.SmartContractController, :audit_reports_list)

    get("/verification/config", V2.VerificationController, :config)
  end

  scope "/", as: :api_v2 do
    pipe_through(:api_v2_no_forgery_protect)

    post("/:address_hash/query-read-method", V2.SmartContractController, :query_read_method)
    post("/:address_hash/audit-reports", V2.SmartContractController, :audit_report_submission)
  end

  scope "/:address_hash/verification/via", as: :api_v2 do
    pipe_through(:api_v2_no_forgery_protect)

    post("/standard-input", V2.VerificationController, :verification_via_standard_input)

    if @chain_type !== :zksync do
      post("/flattened-code", V2.VerificationController, :verification_via_flattened_code)
      post("/sourcify", V2.VerificationController, :verification_via_sourcify)
      post("/multi-part", V2.VerificationController, :verification_via_multi_part)
      post("/vyper-code", V2.VerificationController, :verification_via_vyper_code)
      post("/vyper-multi-part", V2.VerificationController, :verification_via_vyper_multipart)
      post("/vyper-standard-input", V2.VerificationController, :verification_via_vyper_standard_input)
    end

    if @chain_type === :arbitrum do
      post("/stylus-github-repository", V2.VerificationController, :verification_via_stylus_github_repository)
    end
  end
end
