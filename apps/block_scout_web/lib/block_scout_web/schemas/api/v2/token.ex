defmodule BlockScoutWeb.Schemas.API.V2.Token do
  alias OpenApiSpex.Schema
  require OpenApiSpex
  alias BlockScoutWeb.Schemas.API.V2.{ChainTypeCustomizations, General}

  OpenApiSpex.schema(
    ChainTypeCustomizations.token_chain_type_fields(%{
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
        icon_url: %Schema{
          type: :string,
          pattern:
            ~r"/^https?:\/\/(?:www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b(?:[-a-zA-Z0-9()@:%_\+.~#?&\/=]*)$/",
          example:
            "https://raw.githubusercontent.com/trustwallet/assets/master/blockchains/ethereum/assets/0xdAC17F958D2ee523a2206206994597C13D831ec7/logo.png"
        },
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
    })
  )
end
