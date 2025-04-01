defmodule BlockScoutWeb.ApiSpec do
  alias OpenApiSpex.{Info, OpenApi, Paths, Server}
  alias BlockScoutWeb.{Routers.ApiRouter}
  @behaviour OpenApi

  @impl OpenApi
  def spec do
    %OpenApi{
      servers: [
        %Server{url: "https://localhost:4000"}
      ],
      info: %Info{
        title: "Blockscout",
        version: "7.0.0"
      },
      paths: Paths.from_router(ApiRouter)
    }
    |> OpenApiSpex.resolve_schema_modules()
  end
end
