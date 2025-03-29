defmodule BlockScoutWeb.Schemas.API.V2.Address do
  alias OpenApiSpex.Schema
  require OpenApiSpex
  alias BlockScoutWeb.Schemas.API.V2.{ChainTypeCustomizations, General, Proxy}

  @after_compile __MODULE__

  def __after_compile__(env, bytecode) do
    defmodule Response do
      alias BlockScoutWeb.Schemas.API.V2.{ChainTypeCustomizations, General, Token}

      OpenApiSpex.schema(%{
        title: "AddressResponse",
        description: "Address response",
        type: :object,
        allOf: [
          BlockScoutWeb.Schemas.API.V2.Address,
          struct(
            Schema,
            ChainTypeCustomizations.address_response_chain_type_fields(%{
              type: :object,
              properties: %{
                creator_address_hash: General.AddressHashNullable,
                creation_transaction_hash: General.TransactionHashNullable,
                token: %Schema{allOf: [Token], nullable: true},
                coin_balance: General.IntegerStringNullable,
                exchange_rate: General.FloatStringNullable,
                block_number_balance_updated_at: %Schema{type: :integer, minimum: 0, nullable: true},
                has_decompiled_code: %Schema{type: :boolean, nullable: false},
                has_validated_blocks: %Schema{type: :boolean, nullable: false},
                has_logs: %Schema{type: :boolean, nullable: false},
                has_tokens: %Schema{type: :boolean, nullable: false},
                has_token_transfers: %Schema{type: :boolean, nullable: false},
                watchlist_address_id: %Schema{type: :integer, nullable: true},
                has_beacon_chain_withdrawals: %Schema{type: :boolean, nullable: false}
              },
              required: [
                :creator_address_hash,
                :creation_transaction_hash,
                :token,
                :coin_balance,
                :exchange_rate,
                :block_number_balance_updated_at,
                :has_decompiled_code,
                :has_validated_blocks,
                :has_logs,
                :has_tokens,
                :has_token_transfers,
                :watchlist_address_id,
                :has_beacon_chain_withdrawals
              ]
            })
          )
        ]
      })
    end
  end

  OpenApiSpex.schema(
    %{
      description: "Address",
      type: :object,
      properties: %{
        hash: General.AddressHash,
        is_contract: %Schema{type: :boolean, description: "Has address contract code?", nullable: true},
        name: %Schema{type: :string, description: "Name associated with the address", nullable: true},
        is_scam: %Schema{type: :boolean, description: "Has address scam badge?", nullable: false},
        proxy_type: General.ProxyType,
        implementations: %Schema{
          description: "Implementations linked with the contract",
          type: :array,
          items: General.Implementation
        },
        is_verified: %Schema{type: :boolean, description: "Has address associated source code?", nullable: false},
        ens_domain_name: %Schema{
          type: :string,
          description: "ENS domain name associated with the address",
          nullable: true
        },
        metadata: %Schema{allOf: [Proxy.Metadata], nullable: true},
        private_tags: %Schema{
          description: "Private tags associated with the address",
          type: :array,
          items: General.Tag
        },
        watchlist_names: %Schema{
          description: "Watch list name associated with the address",
          type: :array,
          items: General.WatchlistName
        },
        public_tags: %Schema{
          description: "Public tags associated with the address",
          type: :array,
          items: General.Tag
        }
      },
      required: [
        :hash,
        :is_contract,
        :name,
        :is_scam,
        :proxy_type,
        :implementations,
        :is_verified,
        :ens_domain_name,
        :metadata,
        :private_tags,
        :watchlist_names,
        :public_tags
      ]
    }
    |> ChainTypeCustomizations.address_chain_type_fields()
  )
end
