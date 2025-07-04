defmodule BlockScoutWeb.Router do
  use BlockScoutWeb, :router

  use Utils.CompileTimeEnvHelper,
    admin_panel_enabled: [:block_scout_web, :admin_panel_enabled],
    graphql_enabled: [:block_scout_web, [Api.GraphQL, :enabled]],
    api_router_reading_enabled: [:block_scout_web, [BlockScoutWeb.Routers.ApiRouter, :reading_enabled]],
    web_router_enabled: [:block_scout_web, [BlockScoutWeb.Routers.WebRouter, :enabled]]

  alias BlockScoutWeb.Routers.{AccountRouter, ApiRouter}

  @max_query_string_length 5_000

  if @admin_panel_enabled do
    forward("/admin", BlockScoutWeb.Routers.AdminRouter)
  end

  pipeline :browser do
    plug(
      Plug.Parsers,
      parsers: [:urlencoded, :multipart, :json],
      length: 100_000,
      query_string_length: @max_query_string_length,
      pass: ["*/*"],
      json_decoder: Poison
    )

    plug(BlockScoutWeb.Plug.Logger, application: :block_scout_web)
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_flash)
    plug(:protect_from_forgery)
    plug(BlockScoutWeb.CSPHeader)
  end

  pipeline :api do
    plug(
      Plug.Parsers,
      parsers: [:urlencoded, :multipart, :json],
      length: 20_000_000,
      query_string_length: @max_query_string_length,
      pass: ["*/*"],
      json_decoder: Poison
    )

    plug(BlockScoutWeb.Plug.Logger, application: :api)
    plug(BlockScoutWeb.Plug.RateLimit)
    plug(:accepts, ["json"])
  end

  pipeline :api_v1_graphql do
    plug(
      Plug.Parsers,
      parsers: [:json, Absinthe.Plug.Parser],
      json_decoder: Poison,
      body_reader: {BlockScoutWeb.GraphQL.BodyReader, :read_body, []}
    )

    plug(BlockScoutWeb.Plug.Logger, application: :api)
    plug(:accepts, ["json"])
    plug(BlockScoutWeb.Plug.RateLimit)
  end

  pipeline :rate_limit do
    plug(:fetch_query_params)
    plug(:accepts, ["json"])
    plug(BlockScoutWeb.Plug.RateLimit)
  end

  match(:*, "/auth/*path", AccountRouter, [])

  scope "/api" do
    pipe_through(:rate_limit)
    forward("/", ApiRouter)
  end

  scope "/graphiql" do
    pipe_through(:api_v1_graphql)

    if @graphql_enabled && @api_router_reading_enabled do
      forward("/", Absinthe.Plug.GraphiQL,
        schema: BlockScoutWeb.GraphQL.Schema,
        interface: :advanced,
        default_query: BlockScoutWeb.Plug.GraphQL.default_query(),
        socket: BlockScoutWeb.UserSocket
      )
    end
  end

  scope "/", BlockScoutWeb do
    pipe_through(:browser)

    get("/robots.txt", RobotsController, :robots)
    get("/sitemap.xml", RobotsController, :sitemap)

    if @api_router_reading_enabled do
      get("/api-docs", APIDocsController, :index)
      get("/eth-rpc-api-docs", APIDocsController, :eth_rpc)
    else
      get("/api-docs", PageNotFoundController, :index)
      get("/eth-rpc-api-docs", PageNotFoundController, :index)
    end

    if @graphql_enabled do
      get("/schema.graphql", GraphQL.SchemaController, :index)
    end
  end

  scope "/verify_smart_contract" do
    pipe_through(:api)

    post("/contract_verifications", BlockScoutWeb.AddressContractVerificationController, :create)
  end

  if @web_router_enabled do
    forward("/", BlockScoutWeb.Routers.WebRouter)
  end
end
