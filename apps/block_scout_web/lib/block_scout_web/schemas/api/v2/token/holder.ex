# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule BlockScoutWeb.Schemas.API.V2.Token.Holder do
  @moduledoc """
  This module defines the schema for a token holder response.
  Example response:
  {
    "address": { ... },
    "is_burn_address": false,
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
      is_burn_address: %Schema{
        type: :boolean,
        nullable: false,
        description:
          "Whether `address` is the zero address (`0x0000000000000000000000000000000000000000`) or the dead address " <>
            "(`0x000000000000000000000000000000000000dEaD`), whatever the token type. For ERC-20 and ERC-8056 tokens " <>
            "only, `/api/v2/tokens/{address_hash}` reports their balances as `burned_supply`. The zero address is " <>
            "listed for those tokens only, and is not counted in `holders_count`."
      },
      token_id: General.IntegerStringNullable,
      value: General.IntegerStringNullable
    },
    required: [:address, :is_burn_address, :token_id, :value],
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
      is_burn_address: false,
      token_id: nil,
      value: "19474530513868000"
    }
  })
end
