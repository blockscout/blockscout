defmodule BlockScoutWeb.Router do
  use BlockScoutWeb, :router

  alias BlockScoutWeb.Plug.GraphQL
  alias BlockScoutWeb.{ApiRouter, WebRouter}

  if Application.get_env(:block_scout_web, ApiRouter)[:wobserver_enabled] do
    forward("/wobserver", Wobserver.Web.Router)
  end

  forward("/admin", BlockScoutWeb.AdminRouter)

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_flash)
    plug(:protect_from_forgery)
    plug(BlockScoutWeb.CSPHeader)
  end

  pipeline :api do
    plug(:accepts, ["json"])
  end

  forward("/api", ApiRouter)

  if Application.get_env(:block_scout_web, ApiRouter)[:reading_enabled] do
    # Needs to be 200 to support the schema introspection for graphiql
    @max_complexity 200

    forward("/graphql", Absinthe.Plug,
      schema: BlockScoutWeb.Schema,
      analyze_complexity: true,
      max_complexity: @max_complexity
    )

    forward("/graphiql", Absinthe.Plug.GraphiQL,
      schema: BlockScoutWeb.Schema,
      interface: :advanced,
      default_query: GraphQL.default_query(),
      socket: BlockScoutWeb.UserSocket,
      analyze_complexity: true,
      max_complexity: @max_complexity
    )
  else
    scope "/", BlockScoutWeb do
      pipe_through(:browser)
      get("/api-docs", PageNotFoundController, :index)
      get("/eth-rpc-api-docs", PageNotFoundController, :index)
    end
  end

  scope "/", BlockScoutWeb do
    pipe_through(:browser)

    get("/api-docs", APIDocsController, :index)
    get("/eth-rpc-api-docs", APIDocsController, :eth_rpc)
  end

  scope "/verify_smart_contract" do
    pipe_through(:api)

    post("/contract_verifications", BlockScoutWeb.AddressContractVerificationController, :create)
  end

  # if path != api_path do
  #   scope to_string(api_path) <> "/verify_smart_contract" do
  #     pipe_through(:api)

  #     if Application.get_env(:explorer, Explorer.ThirdPartyIntegrations.Sourcify)[:enabled] do
  #       post("/contract_verifications", BlockScoutWeb.AddressContractVerificationController, :create)
  #     else
  #       post("/contract_verifications", BlockScoutWeb.AddressContractVerificationViaFlattenedCodeController, :create)
  #     end
  #   end
  # else
  #   scope "/verify_smart_contract" do
  #     pipe_through(:api)

  #     if Application.get_env(:explorer, Explorer.ThirdPartyIntegrations.Sourcify)[:enabled] do
  #       post("/contract_verifications", BlockScoutWeb.AddressContractVerificationController, :create)
  #     else
  #       post("/contract_verifications", BlockScoutWeb.AddressContractVerificationViaFlattenedCodeController, :create)
  #     end
  #   end
  # end

  if Application.get_env(:block_scout_web, WebRouter)[:enabled] do
    forward("/", BlockScoutWeb.WebRouter)
  else
    scope "/", BlockScoutWeb do
      pipe_through(:browser)

      forward("/", APIDocsController, :index)
    end
  end
end
