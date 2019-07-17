defmodule BlockScoutWeb.Router do
  use BlockScoutWeb, :router

  alias BlockScoutWeb.Plug.GraphQL

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_flash)
    plug(:protect_from_forgery)
    plug(BlockScoutWeb.CSPHeader)
  end

  forward("/wobserver", Wobserver.Web.Router)
  forward("/admin", BlockScoutWeb.AdminRouter)

  if Application.get_env(:block_scout_web, BlockScoutWeb.ApiRouter)[:enabled] do
    forward("/api", BlockScoutWeb.ApiRouter)

    # For backward compatibility. Should be removed
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
  end

  if Application.get_env(:block_scout_web, BlockScoutWeb.WebRouter)[:enabled] do
    forward("/", BlockScoutWeb.WebRouter)
  end
end
