defmodule BlockScoutWeb.Schemas.API.V2.Token.ChainTypeCustomizations do
  @moduledoc false
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.General
  alias BlockScoutWeb.Schemas.Helper
  alias Explorer.Chain.BridgedToken
  alias OpenApiSpex.Schema

  @filecoin_robust_address_schema %Schema{
    type: :string,
    example: "f25nml2cfbljvn4goqtclhifepvfnicv6g7mfmmvq",
    nullable: true
  }

  def chain_type_fields(schema) do
    case Application.get_env(:explorer, :chain_type) do
      :filecoin ->
        schema
        |> Helper.extend_schema(
          properties: %{filecoin_robust_address: @filecoin_robust_address_schema},
          required: [:filecoin_robust_address]
        )

      _ ->
        schema
    end
  end

  def maybe_append_bridged_info(schema) do
    if BridgedToken.enabled?() do
      schema
      |> put_in([:properties, :is_bridged], %Schema{type: :boolean, nullable: false})
      |> update_in([:required], &[:is_bridged | &1])
    else
      schema
    end
  end
end

defmodule BlockScoutWeb.Schemas.API.V2.Token do
  @moduledoc """
  This module defines the schema for the Token struct.
  """
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.General
  alias BlockScoutWeb.Schemas.API.V2.Token.{ChainTypeCustomizations, Type}
  alias Explorer.Chain.Address.Reputation
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(
    %{
      description: "Token struct",
      type: :object,
      properties: %{
        address_hash: General.AddressHash,
        symbol: %Schema{type: :string, nullable: true},
        name: %Schema{type: :string, nullable: true},
        decimals: General.IntegerStringNullable,
        type: %Schema{allOf: [Type], nullable: true},
        holders_count: General.IntegerStringNullable,
        exchange_rate: General.FloatStringNullable,
        volume_24h: General.FloatStringNullable,
        total_supply: General.IntegerStringNullable,
        icon_url: General.URLNullable,
        circulating_market_cap: General.FloatStringNullable,
        reputation: %Schema{
          type: :string,
          enum: Reputation.enum_values(),
          description: "Reputation of the token",
          nullable: true
        },
        bridge_type: %Schema{
          type: :string,
          enum: ["omni", "amb"],
          description: "Type of bridge used for this bridged token",
          nullable: true
        },
        foreign_address: %Schema{type: :string, pattern: General.address_hash_pattern(), nullable: true},
        origin_chain_id: General.IntegerStringNullable
      },
      required: [
        :address_hash,
        :symbol,
        :name,
        :decimals,
        :type,
        :holders_count,
        :exchange_rate,
        :volume_24h,
        :total_supply,
        :icon_url,
        :circulating_market_cap,
        :reputation
      ],
      additionalProperties: false
    }
    |> ChainTypeCustomizations.chain_type_fields()
    |> ChainTypeCustomizations.maybe_append_bridged_info()
  )
end

defmodule BlockScoutWeb.Schemas.API.V2.Token.Type do
  @moduledoc """
  This module defines the schema for the Token type.
  """
  require OpenApiSpex

  OpenApiSpex.schema(%{
    type: :string,
    enum: [
      "ERC-20",
      "ERC-721",
      "ERC-1155",
      "ERC-404"
    ]
  })
end
