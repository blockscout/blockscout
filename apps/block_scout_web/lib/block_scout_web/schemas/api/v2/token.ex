defmodule BlockScoutWeb.Schemas.API.V2.Token.ChainTypeCustomizations do
  @moduledoc false
  require OpenApiSpex

  alias OpenApiSpex.Schema

  use Utils.CompileTimeEnvHelper, chain_type: [:explorer, :chain_type]

  case @chain_type do
    :filecoin ->
      @filecoin_robust_address_schema %Schema{
        type: :string,
        example: "f25nml2cfbljvn4goqtclhifepvfnicv6g7mfmmvq",
        nullable: true
      }

      def token_chain_type_fields(schema) do
        schema
        |> put_in([:properties, :filecoin_robust_address], @filecoin_robust_address_schema)
        |> update_in([:required], &[:filecoin_robust_address | &1])
      end

    _ ->
      def token_chain_type_fields(schema), do: schema
  end
end

defmodule BlockScoutWeb.Schemas.API.V2.Token do
  @moduledoc """
  This module defines the schema for the Token struct.
  """
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.General
  alias BlockScoutWeb.Schemas.API.V2.Token.ChainTypeCustomizations
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(
    %{
      description: "Token struct",
      type: :object,
      properties: %{
        address: General.AddressHash,
        symbol: %Schema{type: :string, nullable: false},
        name: %Schema{type: :string, nullable: false},
        decimals: General.IntegerStringNullable,
        type: %Schema{
          type: :string,
          enum: [
            "ERC-20",
            "ERC-721",
            "ERC-1155",
            "ERC-404"
          ],
          nullable: true
        },
        holders: General.IntegerStringNullable,
        exchange_rate: General.FloatStringNullable,
        volume_24h: General.FloatStringNullable,
        total_supply: General.IntegerStringNullable,
        icon_url: General.URLNullable,
        circulating_market_cap: General.FloatStringNullable,
        is_bridged: %Schema{type: :boolean, nullable: false}
      },
      required: [
        :address,
        :symbol,
        :name,
        :decimals,
        :type,
        :holders,
        :exchange_rate,
        :volume_24h,
        :total_supply,
        :icon_url,
        :circulating_market_cap
      ]
    }
    |> ChainTypeCustomizations.token_chain_type_fields()
  )
end
