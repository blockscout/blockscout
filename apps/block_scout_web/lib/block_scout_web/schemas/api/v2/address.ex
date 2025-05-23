defmodule BlockScoutWeb.Schemas.API.V2.Address.ChainTypeCustomizations do
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

      def address_chain_type_fields(schema) do
        schema
        |> put_in([:properties, :filecoin], %Schema{
          type: :object,
          properties: %{
            id: %Schema{type: :string, example: "f03248220", nullable: true},
            robust: @filecoin_robust_address_schema,
            actor_type: %Schema{
              type: :string,
              # credo:disable-for-next-line
              enum: Ecto.Enum.values(Explorer.Chain.Address, :filecoin_actor_type),
              nullable: true
            }
          }
        })
      end

      def address_response_chain_type_fields(schema) do
        schema
        |> put_in([:properties, :creator_filecoin_robust_address], @filecoin_robust_address_schema)
        |> update_in([:required], &[:creator_filecoin_robust_address | &1])
      end

    :zilliqa ->
      def address_chain_type_fields(schema), do: schema

      def address_response_chain_type_fields(schema) do
        schema
        |> put_in([:properties, :is_scilla_contract], %Schema{type: :boolean, nullable: false})
      end

    _ ->
      def address_chain_type_fields(schema), do: schema

      def address_response_chain_type_fields(schema), do: schema
  end
end

defmodule BlockScoutWeb.Schemas.API.V2.Address do
  @moduledoc """
  This module defines the schema for address struct, returned by BlockScoutWeb.API.V2.Helper.address_with_info/5.

  Note that BlockScoutWeb.Schemas.API.V2.Address.Response is defined in __after_compile__/2 callback. This is done to reuse the Address schema in the AddressResponse schema.
  """
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.Address.ChainTypeCustomizations
  alias BlockScoutWeb.Schemas.API.V2.{General, Proxy}
  alias OpenApiSpex.Schema

  @after_compile __MODULE__

  def __after_compile__(env, bytecode) do
    defmodule Response do
      @moduledoc """
      This module defines the schema for address response from /api/v2/addresses/:hash.
      """

      alias BlockScoutWeb.Schemas.API.V2.Address.ChainTypeCustomizations
      alias BlockScoutWeb.Schemas.API.V2.{General, Token}

      OpenApiSpex.schema(%{
        title: "AddressResponse",
        description: "Address response",
        type: :object,
        allOf: [
          BlockScoutWeb.Schemas.API.V2.Address,
          struct(
            Schema,
            %{
              type: :object,
              properties: %{
                creator_address_hash: General.AddressHashNullable,
                creation_transaction_hash: General.FullHashNullable,
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
            }
            |> ChainTypeCustomizations.address_response_chain_type_fields()
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
