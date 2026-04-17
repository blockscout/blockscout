defmodule BlockScoutWeb.Specs.Private do
  @moduledoc """
  This module defines the private API specification for the BlockScoutWeb application.
  """

  alias BlockScoutWeb.Routers.AccountRouter
  alias BlockScoutWeb.Specs
  alias OpenApiSpex.{Components, Contact, Info, OpenApi, Paths, SecurityScheme, Server}
  alias Utils.Helper

  @behaviour OpenApi

  @impl OpenApi
  def spec do
    %OpenApi{
      servers: [
        %Server{url: to_string(Helper.instance_url() |> URI.append_path("/api"))}
      ],
      info: %Info{
        title: "Blockscout Private API",
        version: to_string(Application.spec(:block_scout_web, :vsn)),
        contact: %Contact{
          email: "info@blockscout.com"
        }
      },
      paths: Paths.from_routes(Specs.routes_with_prefix(AccountRouter, "/account")),
      components: %Components{
        securitySchemes: %{"dynamic_jwt" => %SecurityScheme{type: "http", scheme: "bearer", bearerFormat: "JWT"}}
      }
    }
    |> OpenApiSpex.resolve_schema_modules()
  end
end
