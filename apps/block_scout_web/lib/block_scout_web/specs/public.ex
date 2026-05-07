defmodule BlockScoutWeb.Specs.Public do
  @moduledoc """
  This module defines the public API specification for the BlockScoutWeb application.
  """

  alias BlockScoutWeb.Routers.{ApiRouter, SmartContractsApiV2Router, TokensApiV2Router}
  alias BlockScoutWeb.Specs
  alias OpenApiSpex.{Contact, Info, OpenApi, Paths, Server, Tag}
  alias Utils.Helper

  use Utils.CompileTimeEnvHelper,
    chain_identity: [:explorer, :chain_identity]

  use Utils.RuntimeEnvHelper,
    mud_enabled?: [:explorer, [Explorer.Chain.Mud, :enabled]]

  @behaviour OpenApi

  @default_api_categories [
    "blocks",
    "transactions",
    "addresses",
    "internal-transactions",
    "tokens",
    "token-transfers",
    "smart-contracts",
    "config",
    "main-page",
    "search",
    "stats",
    "csv-export",
    "account-abstraction",
    "withdrawals"
  ]

  # todo: if new chain type is covered with OpenAPI specs
  # modify this to support proper ordering:
  # 1. default endpoints
  # 2. chain-type specific endpoints (e.g. optimism, celo, scroll, zilliqa)
  # 3. legacy endpoints
  case @chain_identity do
    {:optimism, :celo} ->
      @chain_type_category_tags [%Tag{name: "optimism"}, %Tag{name: "celo"}]
      defp chain_type_category_tags, do: @chain_type_category_tags

    {:optimism, nil} ->
      defp chain_type_category_tags do
        if mud_enabled?() do
          [%Tag{name: "optimism"}, %Tag{name: "mud"}]
        else
          [%Tag{name: "optimism"}]
        end
      end

    {chain_type, nil} when chain_type in [:scroll, :zilliqa] ->
      @chain_type_category_tags [%Tag{name: to_string(chain_type)}]
      defp chain_type_category_tags, do: @chain_type_category_tags

    _ ->
      @chain_type_category_tags []
      defp chain_type_category_tags, do: @chain_type_category_tags
  end

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
      paths:
        ApiRouter
        |> Paths.from_router()
        |> Map.merge(Paths.from_routes(Specs.routes_with_prefix(TokensApiV2Router, "/v2/tokens")))
        |> Map.merge(Paths.from_routes(Specs.routes_with_prefix(SmartContractsApiV2Router, "/v2/smart-contracts"))),
      tags:
        Enum.map(@default_api_categories, fn category -> %Tag{name: category} end) ++
          chain_type_category_tags() ++ [%Tag{name: "legacy"}]
    }
    |> OpenApiSpex.resolve_schema_modules()
  end
end
