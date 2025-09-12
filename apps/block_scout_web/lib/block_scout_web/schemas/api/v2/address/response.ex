defmodule BlockScoutWeb.Schemas.API.V2.Address.Response.ChainTypeCustomizations do
  @moduledoc false
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.Address
  alias OpenApiSpex.Schema

  @filecoin_robust_address_schema %Schema{
    type: :string,
    description: "Robust f0/f1/f2/f3/f4 Filecoin address",
    example: "f25nml2cfbljvn4goqtclhifepvfnicv6g7mfmmvq",
    nullable: true
  }

  @zilliqa_schema %Schema{
    type: :object,
    properties: %{
      is_scilla_contract: %Schema{type: :boolean, nullable: false}
    },
    required: [:is_scilla_contract]
  }

  @celo_schema %Schema{
    type: :object,
    properties: %{
      account: %Schema{
        type: :object,
        nullable: true,
        properties: %{
          type: %Schema{
            type: :string,
            enum: [:regular, :validator, :group],
            nullable: false
          },
          name: %Schema{type: :string, nullable: true},
          metadata_url: %Schema{type: :string, nullable: true},
          nonvoting_locked_celo: %Schema{type: :string, nullable: false},
          locked_celo: %Schema{type: :string, nullable: false},
          vote_signer_address: Address,
          validator_signer_address: Address,
          attestation_signer_address: Address
        },
        required: [
          :type,
          :name,
          :metadata_url,
          :nonvoting_locked_celo,
          :locked_celo,
          :vote_signer_address,
          :validator_signer_address,
          :attestation_signer_address
        ],
        example: %{
          type: "validator",
          name: "Celo Validator",
          metadata_url: "https://example.com/metadata",
          nonvoting_locked_celo: "1000000000000000000",
          locked_celo: "2000000000000000000"
        }
      }
    },
    required: [:account]
  }

  @doc """
   Applies chain-specific field customizations to the given schema based on the configured chain type.

   ## Parameters
   - `schema`: The base schema map to be customized

   ## Returns
   - The schema map with chain-specific properties added based on the current chain type configuration
  """
  @spec chain_type_fields(map()) :: map()
  def chain_type_fields(schema) do
    case Application.get_env(:explorer, :chain_type) do
      :filecoin ->
        schema
        |> put_in([:properties, :creator_filecoin_robust_address], @filecoin_robust_address_schema)
        |> update_in([:required], &[:creator_filecoin_robust_address | &1])

      :zilliqa ->
        schema
        |> put_in([:properties, :zilliqa], @zilliqa_schema)
        |> update_in([:required], &[:zilliqa | &1])

      :celo ->
        schema
        |> put_in([:properties, :celo], @celo_schema)
        |> update_in([:required], &[:celo | &1])

      _ ->
        schema
    end
  end
end

defmodule BlockScoutWeb.Schemas.API.V2.Address.Response do
  @moduledoc """
  This module defines the schema for address response from /api/v2/addresses/:hash.
  """
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.Address.Response.ChainTypeCustomizations
  alias BlockScoutWeb.Schemas.API.V2.{General, Token}
  alias OpenApiSpex.Schema

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
            has_validated_blocks: %Schema{type: :boolean, nullable: false},
            has_logs: %Schema{type: :boolean, nullable: false},
            has_tokens: %Schema{type: :boolean, nullable: false},
            has_token_transfers: %Schema{type: :boolean, nullable: false},
            watchlist_address_id: %Schema{type: :integer, nullable: true},
            has_beacon_chain_withdrawals: %Schema{type: :boolean, nullable: false},
            creation_status: %Schema{
              type: :string,
              description: "Creation status of the contract",
              enum: ["success", "failed", "selfdestructed"],
              nullable: true
            }
          },
          required: [
            :creator_address_hash,
            :creation_transaction_hash,
            :token,
            :coin_balance,
            :exchange_rate,
            :block_number_balance_updated_at,
            :has_validated_blocks,
            :has_logs,
            :has_tokens,
            :has_token_transfers,
            :watchlist_address_id,
            :has_beacon_chain_withdrawals,
            :creation_status
          ]
        }
        |> ChainTypeCustomizations.chain_type_fields()
      )
    ]
  })
end
