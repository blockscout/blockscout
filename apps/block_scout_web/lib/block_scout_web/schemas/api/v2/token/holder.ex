defmodule BlockScoutWeb.Schemas.API.V2.Token.Holder do
  @moduledoc """
  This module defines the schema for a token holder response.
  Example response:
  {
    "address": { ... },
    "token_id": null,
    "value": "19474530513868000"
  }
  """
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.{Address, General}
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%Schema{
    title: "TokenHolderResponse",
    description: "Token holder response",
    type: :object,
    properties: %{
      address: Address.schema(),
      token_id: General.IntegerStringNullable,
      value: General.IntegerStringNullable
    },
    required: [:address, :token_id, :value],
    additionalProperties: false,
    example: %{
      address: %{
        ens_domain_name: nil,
        hash: "0xF977814e90dA44bFA03b6295A0616a897441aceC",
        implementations: [],
        is_contract: false,
        is_scam: false,
        is_verified: false,
        metadata: %{
          tags: [
            %{
              meta: %{main_entity: "Binance", tooltipUrl: "https://www.binance.com/"},
              name: "Binance: Hot Wallet 20",
              ordinal: 10,
              slug: "binance-hot-wallet-20",
              tagType: "name"
            },
            %{
              meta: %{tooltipUrl: "https://www.binance.com"},
              name: "Binance 8",
              ordinal: 10,
              slug: "binance-8",
              tagType: "name"
            },
            %{
              meta: %{},
              name: "HOT WALLET",
              ordinal: 0,
              slug: "hot-wallet",
              tagType: "generic"
            },
            %{
              meta: %{},
              name: "Exchange",
              ordinal: 0,
              slug: "exchange",
              tagType: "generic"
            },
            %{
              meta: %{},
              name: "Binance",
              ordinal: 0,
              slug: "binance",
              tagType: "protocol"
            }
          ]
        },
        name: nil,
        private_tags: [],
        proxy_type: nil,
        public_tags: [],
        reputation: "ok",
        watchlist_names: []
      },
      token_id: nil,
      value: "19474530513868000"
    }
  })
end
