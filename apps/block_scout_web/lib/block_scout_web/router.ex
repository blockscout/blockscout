defmodule BlockScoutWeb.Router do
  use BlockScoutWeb, :router

  alias BlockScoutWeb.Plug.{GraphQL, RateLimit}
  alias BlockScoutWeb.{ApiRouter, WebRouter}

  @max_query_string_length 5_000

  if Application.compile_env(:block_scout_web, :admin_panel_enabled) do
    forward("/admin", BlockScoutWeb.AdminRouter)
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
    plug(RateLimit, graphql?: true)
  end

  forward("/api", ApiRouter)

  scope "/graphiql" do
    pipe_through(:api_v1_graphql)

    if Application.compile_env(:block_scout_web, Api.GraphQL)[:enabled] &&
         Application.compile_env(:block_scout_web, ApiRouter)[:reading_enabled] do
      forward("/", Absinthe.Plug.GraphiQL,
        schema: BlockScoutWeb.GraphQL.Schema,
        interface: :advanced,
        default_query: GraphQL.default_query(),
        socket: BlockScoutWeb.UserSocket
      )
    end
  end

  scope "/", BlockScoutWeb do
    pipe_through(:browser)

    get("/robots.txt", RobotsController, :robots)
    get("/sitemap.xml", RobotsController, :sitemap)

    if Application.compile_env(:block_scout_web, ApiRouter)[:reading_enabled] do
      get("/api-docs", APIDocsController, :index)
      get("/eth-rpc-api-docs", APIDocsController, :eth_rpc)
    else
      get("/api-docs", PageNotFoundController, :index)
      get("/eth-rpc-api-docs", PageNotFoundController, :index)
    end
  end

  scope "/verify_smart_contract" do
    pipe_through(:api)

    post("/contract_verifications", BlockScoutWeb.AddressContractVerificationController, :create)
  end

  if Application.compile_env(:block_scout_web, WebRouter)[:enabled] do
    forward("/", BlockScoutWeb.WebRouter)
  end
end
