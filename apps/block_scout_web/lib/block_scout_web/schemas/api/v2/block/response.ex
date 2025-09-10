defmodule BlockScoutWeb.Schemas.API.V2.Block.Response.ChainTypeCustomizations do
  @moduledoc false
  require OpenApiSpex

  alias OpenApiSpex.Schema

  @arbitrum_schema %Schema{
    type: :object,
    properties: %{
      batch_number: %Schema{type: :integer, nullable: true},
      commitment_transaction_hash: %Schema{type: :string, nullable: true},
      confirmation_transaction_hash: %Schema{type: :string, nullable: true}
    }
  }

  @optimism_schema %Schema{
    type: :object,
    properties: %{
      frame_sequence: %Schema{type: :integer, nullable: true}
    }
  }

  @zksync_schema %Schema{
    type: :object,
    properties: %{
      batch_number: %Schema{type: :integer, nullable: true},
      commit_transaction_hash: %Schema{type: :string, nullable: true},
      prove_transaction_hash: %Schema{type: :string, nullable: true},
      execute_transaction_hash: %Schema{type: :string, nullable: true}
    }
  }

  @zilliqa_schema %Schema{
    type: :object,
    properties: %{
      quorum_certificate: %Schema{type: :object, nullable: true},
      aggregate_quorum_certificate: %Schema{type: :object, nullable: true}
    }
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
      :arbitrum ->
        schema
        |> put_in([:properties, :arbitrum], @arbitrum_schema)
        |> update_in([:required], &[:arbitrum | &1])

      :optimism ->
        schema
        |> put_in([:properties, :optimism], @optimism_schema)
        |> update_in([:required], &[:optimism | &1])

      :zksync ->
        schema
        |> put_in([:properties, :zksync], @zksync_schema)
        |> update_in([:required], &[:zksync | &1])

      :zilliqa ->
        schema
        |> put_in([:properties, :zilliqa], @zilliqa_schema)
        |> update_in([:required], &[:zilliqa | &1])

      _ ->
        schema
    end
  end
end

defmodule BlockScoutWeb.Schemas.API.V2.Block.Response do
  @moduledoc """
  This module defines the schema for block response from /api/v2/blocks/:hash_or_number.
  """
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.Block.Response.ChainTypeCustomizations
  alias BlockScoutWeb.Schemas.API.V2.General
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "BlockResponse",
    description: "Block response",
    type: :object,
    allOf: [
      BlockScoutWeb.Schemas.API.V2.Block,
      struct(
        Schema,
        %{
          type: :object,
          properties: %{
            burnt_fees: General.IntegerStringNullable,
            burnt_fees_percentage: %Schema{type: :number, format: :float, nullable: true},
            difficulty: General.IntegerStringNullable,
            withdrawals_count: %Schema{type: :integer, minimum: 0, nullable: true},
            beacon_deposits_count: %Schema{type: :integer, minimum: 0, nullable: true},
            blob_tx_count: %Schema{type: :integer, minimum: 0, nullable: true},
            priority_fee: General.IntegerStringNullable,
            base_fee_per_gas: General.IntegerStringNullable,
            blob_gas_price: General.IntegerStringNullable,
            blob_gas_used: General.IntegerStringNullable,
            excess_blob_gas: General.IntegerStringNullable,
            uncles: %Schema{
              type: :array,
              items: General.FullHash,
              nullable: true
            },
            rewards: %Schema{
              type: :array,
              items: %Schema{
                type: :object,
                properties: %{
                  address_hash: General.AddressHash,
                  reward: General.IntegerString,
                  type: %Schema{type: :string}
                },
                required: [:address_hash, :reward, :type]
              },
              nullable: true
            }
          },
          required: [
            :burnt_fees,
            :burnt_fees_percentage,
            :priority_fee,
            :base_fee_per_gas,
            :rewards
          ]
        }
        |> ChainTypeCustomizations.chain_type_fields()
      )
    ]
  })
end
