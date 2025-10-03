defmodule BlockScoutWeb.ApiSpec do
  @moduledoc """
  This module defines the API specification for the BlockScoutWeb application.
  """
  alias BlockScoutWeb.Routers.{ApiRouter, TokensApiV2Router}
  alias OpenApiSpex.{Contact, Info, OpenApi, Paths, Server}
  alias Utils.Helper

  @behaviour OpenApi

  @impl OpenApi
  def spec do
    %OpenApi{
      servers: [
        %Server{url: to_string(Helper.instance_url() |> URI.append_path("/api"))}
      ],
      info: %Info{
        title: "Blockscout",
        version: to_string(Application.spec(:block_scout_web, :vsn)),
        contact: %Contact{
          email: "info@blockscout.com"
        }
      },
      paths: ApiRouter |> Paths.from_router() |> Map.merge(Paths.from_router(TokensApiV2Router))
    }
    |> OpenApiSpex.resolve_schema_modules()
  end
end
