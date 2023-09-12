defmodule BlockScoutWeb.Router do
  use BlockScoutWeb, :router

  alias BlockScoutWeb.Plug.GraphQL
  alias BlockScoutWeb.{ApiRouter, WebRouter}

  if Application.compile_env(:block_scout_web, :admin_panel_enabled) do
    forward("/admin", BlockScoutWeb.AdminRouter)
  end

  pipeline :browser do
    plug(BlockScoutWeb.Plug.Logger, application: :block_scout_web)
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_flash)
    plug(:protect_from_forgery)
    plug(BlockScoutWeb.CSPHeader)
  end

  pipeline :api do
    plug(BlockScoutWeb.Plug.Logger, application: :api)
    plug(:accepts, ["json"])
  end

  forward("/api", ApiRouter)

  if Application.compile_env(:block_scout_web, ApiRouter)[:reading_enabled] do
    # Needs to be 200 to support the schema introspection for graphiql
    @max_complexity 200

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

    get("/robots.txt", RobotsController, :robots)
    get("/sitemap.xml", RobotsController, :sitemap)
    get("/api-docs", APIDocsController, :index)
    get("/eth-rpc-api-docs", APIDocsController, :eth_rpc)
  end

  scope "/verify_smart_contract" do
    pipe_through(:api)

    post("/contract_verifications", BlockScoutWeb.AddressContractVerificationController, :create)
  end

  if Application.compile_env(:block_scout_web, WebRouter)[:enabled] do
    forward("/", BlockScoutWeb.WebRouter)
  else
    scope "/", BlockScoutWeb do
      pipe_through(:browser)

      forward("/", APIDocsController, :index)
    end
  end
end
