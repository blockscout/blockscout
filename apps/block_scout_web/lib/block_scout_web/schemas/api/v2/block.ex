defmodule BlockScoutWeb.Schemas.API.V2.Block.ChainTypeCustomizations do
  @moduledoc false
  alias BlockScoutWeb.API.V2.ZkSyncView
  alias BlockScoutWeb.Schemas.API.V2.{Address, General, Token}
  alias BlockScoutWeb.Schemas.Helper
  alias OpenApiSpex.Schema

  use Utils.RuntimeEnvHelper,
    chain_type: [:explorer, :chain_type],
    chain_identity: [:explorer, :chain_identity]

  @zksync_schema %Schema{
    type: :object,
    nullable: false,
    properties: %{
      batch_number: %Schema{type: :integer, nullable: true},
      status: %Schema{
        type: :string,
        enum: ZkSyncView.batch_status_enum(),
        nullable: false
      },
      commit_transaction_hash: General.FullHashNullable,
      commit_transaction_timestamp: General.TimestampNullable,
      prove_transaction_hash: General.FullHashNullable,
      prove_transaction_timestamp: General.TimestampNullable,
      execute_transaction_hash: General.FullHashNullable,
      execute_transaction_timestamp: General.TimestampNullable
    },
    required: [
      :batch_number,
      :status,
      :commit_transaction_hash,
      :commit_transaction_timestamp,
      :prove_transaction_hash,
      :prove_transaction_timestamp,
      :execute_transaction_hash,
      :execute_transaction_timestamp
    ],
    additionalProperties: false
  }

  @arbitrum_schema %Schema{
    type: :object,
    nullable: false,
    properties: %{
      batch_number: %Schema{type: :integer, nullable: true},
      batch_data_container: %Schema{
        type: :string,
        nullable: true,
        enum: ["in_blob4844", "in_calldata", "in_celestia", "in_anytrust", "in_eigenda"]
      },
      status: %Schema{
        type: :string,
        enum: ["Confirmed on base", "Sent to base", "Sealed on rollup", "Processed on rollup"],
        nullable: false
      },
      commitment_transaction: %Schema{
        type: :object,
        nullable: false,
        properties: %{
          hash: General.FullHashNullable,
          timestamp: General.TimestampNullable,
          status: %Schema{type: :string, enum: ["unfinalized", "finalized"], nullable: true}
        },
        required: [:hash, :timestamp, :status]
      },
      confirmation_transaction: %Schema{
        type: :object,
        nullable: false,
        properties: %{
          hash: General.FullHashNullable,
          timestamp: General.TimestampNullable,
          status: %Schema{type: :string, enum: ["unfinalized", "finalized"], nullable: true}
        },
        required: [:hash, :timestamp, :status]
      },
      delayed_messages: %Schema{type: :integer, nullable: false},
      l1_block_number: %Schema{type: :integer, nullable: true},
      send_count: %Schema{type: :integer, nullable: true},
      send_root: General.FullHashNullable
    },
    required: [:batch_number, :status, :commitment_transaction, :confirmation_transaction],
    additionalProperties: false
  }

  @blob4844_schema %Schema{
    type: :object,
    nullable: false,
    properties: %{
      hash: General.FullHashNullable,
      l1_transaction_hash: General.FullHashNullable,
      l1_timestamp: General.TimestampNullable
    },
    required: [:hash, :l1_transaction_hash, :l1_timestamp],
    additionalProperties: false
  }

  @doc """
    Returns the Blob4844 schema.
  """
  @spec blob4844_schema() :: Schema.t()
  def blob4844_schema, do: @blob4844_schema

  @celestia_schema %Schema{
    type: :object,
    nullable: false,
    properties: %{
      height: %Schema{type: :integer, nullable: true},
      namespace: %Schema{type: :string, nullable: true},
      commitment: %Schema{type: :string, nullable: true},
      l1_transaction_hash: General.FullHashNullable,
      l1_timestamp: General.TimestampNullable
    },
    required: [:height, :namespace, :commitment, :l1_transaction_hash, :l1_timestamp],
    additionalProperties: false
  }

  @alt_da_schema %Schema{
    type: :object,
    nullable: false,
    properties: %{
      commitment: %Schema{type: :string, nullable: true},
      l1_transaction_hash: General.FullHashNullable,
      l1_timestamp: General.TimestampNullable
    },
    required: [:commitment, :l1_transaction_hash, :l1_timestamp]
  }

  @doc """
    Returns the Celestia schema.
  """
  @spec celestia_schema() :: Schema.t()
  def celestia_schema, do: @celestia_schema

  @optimism_schema %Schema{
    type: :object,
    nullable: false,
    properties: %{
      number: %Schema{type: :integer, nullable: true},
      l1_timestamp: General.TimestampNullable,
      l1_transaction_hashes: %Schema{type: :array, items: General.FullHash, nullable: false},
      batch_data_container: %Schema{
        type: :string,
        nullable: false,
        enum: ["in_blob4844", "in_celestia", "in_alt_da", "in_calldata"]
      },
      blobs: %Schema{
        type: :array,
        items: %Schema{anyOf: [@blob4844_schema, @celestia_schema, @alt_da_schema]},
        nullable: false
      }
    },
    required: [:number, :l1_timestamp, :l1_transaction_hashes, :batch_data_container],
    additionalProperties: false
  }

  @celo_schema %Schema{
    type: :object,
    nullable: false,
    properties: %{
      is_epoch_block: %Schema{type: :boolean, nullable: false},
      epoch_number: %Schema{type: :integer, nullable: false},
      l1_era_finalized_epoch_number: %Schema{type: :integer, nullable: true},
      base_fee: %Schema{
        type: :object,
        nullable: true,
        properties: %{
          recipient: Address,
          amount: General.IntegerString,
          token: Token,
          breakdown: %Schema{
            type: :array,
            items: %Schema{
              type: :object,
              properties: %{
                address: Address,
                amount: General.IntegerString,
                percentage: %Schema{type: :number, nullable: false}
              },
              required: [:address, :amount, :percentage],
              additionalProperties: false
            },
            nullable: false
          }
        },
        required: [:recipient, :amount, :token, :breakdown],
        additionalProperties: false
      }
    },
    required: [:is_epoch_block, :epoch_number, :l1_era_finalized_epoch_number],
    additionalProperties: false
  }

  @zilliqa_schema %Schema{
    type: :object,
    nullable: false,
    properties: %{
      view: %Schema{type: :integer, nullable: true},
      quorum_certificate: %Schema{
        type: :object,
        nullable: false,
        properties: %{
          view: %Schema{type: :integer, nullable: false},
          signature: General.HexString,
          signers: %Schema{type: :array, items: %Schema{type: :integer, nullable: false}, nullable: false}
        },
        required: [:view, :signature, :signers],
        additionalProperties: false
      },
      aggregate_quorum_certificate: %Schema{
        type: :object,
        nullable: false,
        properties: %{
          view: %Schema{type: :integer, nullable: false},
          signature: General.HexString,
          signers: %Schema{type: :array, items: %Schema{type: :integer, nullable: false}, nullable: false},
          nested_quorum_certificates: %Schema{
            type: :array,
            items: %Schema{
              type: :object,
              properties: %{
                view: %Schema{type: :integer, nullable: false},
                signature: General.HexString,
                proposed_by_validator_index: %Schema{type: :integer, nullable: false},
                signers: %Schema{type: :array, items: %Schema{type: :integer, nullable: false}, nullable: false}
              },
              required: [:view, :signature, :proposed_by_validator_index, :signers],
              additionalProperties: false
            },
            nullable: false
          }
        },
        required: [:view, :signature, :signers, :nested_quorum_certificates],
        additionalProperties: false
      }
    },
    required: [:view],
    additionalProperties: false
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
    chain_type()
    |> case do
      :rsk ->
        schema
        |> Helper.extend_schema(
          properties: %{
            minimum_gas_price: General.IntegerString,
            bitcoin_merged_mining_header: General.HexString,
            bitcoin_merged_mining_coinbase_transaction: General.HexString,
            bitcoin_merged_mining_merkle_proof: General.HexString,
            hash_for_merged_mining: General.FullHash
          }
        )

      :optimism ->
        schema |> Helper.extend_schema(properties: %{optimism: @optimism_schema})

      :zksync ->
        schema |> Helper.extend_schema(properties: %{zksync: @zksync_schema})

      :arbitrum ->
        schema |> Helper.extend_schema(properties: %{arbitrum: @arbitrum_schema})

      :ethereum ->
        schema
        |> Helper.extend_schema(
          properties: %{
            blob_transactions_count: %Schema{type: :integer, minimum: 0, nullable: false},
            blob_gas_used: General.IntegerStringNullable,
            excess_blob_gas: General.IntegerStringNullable,
            blob_gas_price: General.IntegerStringNullable,
            burnt_blob_fees: General.IntegerString,
            beacon_deposits_count: %Schema{type: :integer, minimum: 0, nullable: true}
          },
          required: [:blob_transactions_count, :blob_gas_used, :excess_blob_gas, :beacon_deposits_count]
        )

      :zilliqa ->
        schema |> Helper.extend_schema(properties: %{zilliqa: @zilliqa_schema})

      _ ->
        schema
    end
    |> chain_identity_fields()
  end

  defp chain_identity_fields(schema) do
    case chain_identity() do
      {:optimism, :celo} ->
        schema |> Helper.extend_schema(properties: %{celo: @celo_schema})

      _ ->
        schema
    end
  end
end

defmodule BlockScoutWeb.Schemas.API.V2.Block.Common do
  @moduledoc """
  This module defines common schema fields for block.
  """
  alias BlockScoutWeb.Schemas.API.V2.{Address, General}
  alias OpenApiSpex.Schema

  @required_fields [
    :height,
    :timestamp,
    :transactions_count,
    :internal_transactions_count,
    :miner,
    :size,
    :hash,
    :parent_hash,
    :difficulty,
    :total_difficulty,
    :gas_used,
    :gas_limit,
    :nonce,
    :base_fee_per_gas,
    :burnt_fees,
    :priority_fee,
    :uncles_hashes,
    :rewards,
    :gas_target_percentage,
    :gas_used_percentage,
    :burnt_fees_percentage,
    :type,
    :transaction_fees,
    :withdrawals_count,
    :is_pending_update
  ]

  @rewards_schema %Schema{
    type: :array,
    items: %Schema{
      type: :object,
      properties: %{
        address_hash: General.AddressHash,
        reward: General.IntegerString,
        type: %Schema{type: :string, nullable: false}
      },
      required: [:type, :reward],
      additionalProperties: false
    },
    nullable: false
  }

  @doc """
    Returns the common rewards schema for block.
  """
  @spec rewards_schema() :: Schema.t()
  def rewards_schema, do: @rewards_schema

  @doc """
    Returns the list of required fields for the block schema.
  """
  @spec required_fields() :: [atom()]
  def required_fields, do: @required_fields

  @doc """
    Returns the common schema for block.
  """
  @spec schema() :: map()
  def schema do
    %{
      type: :object,
      properties: %{
        height: %Schema{type: :integer, nullable: false, minimum: 0},
        timestamp: General.Timestamp,
        transactions_count: %Schema{type: :integer, nullable: false},
        internal_transactions_count: %Schema{type: :integer, nullable: true},
        miner: Address,
        size: %Schema{type: :integer, nullable: false},
        hash: General.FullHash,
        parent_hash: General.FullHash,
        difficulty: General.IntegerStringNullable,
        total_difficulty: General.IntegerStringNullable,
        gas_used: General.IntegerString,
        gas_limit: General.IntegerString,
        nonce: General.HexStringNullable,
        base_fee_per_gas: General.IntegerStringNullable,
        burnt_fees: General.IntegerStringNullable,
        priority_fee: General.IntegerStringNullable,
        uncles_hashes: %Schema{
          type: :array,
          items: %Schema{
            type: :object,
            properties: %{hash: General.FullHash},
            required: [:hash],
            nullable: false,
            additionalProperties: false
          },
          nullable: false
        },
        rewards: @rewards_schema,
        gas_target_percentage: %Schema{type: :number, format: :float, nullable: false},
        gas_used_percentage: %Schema{type: :number, format: :float, nullable: false},
        burnt_fees_percentage: %Schema{type: :number, format: :float, nullable: true},
        type: %Schema{type: :string, nullable: false, enum: ["block", "uncle", "reorg"]},
        transaction_fees: General.IntegerString,
        withdrawals_count: %Schema{type: :integer, minimum: 0, nullable: true},
        is_pending_update: %Schema{type: :boolean, nullable: false}
      },
      required: required_fields(),
      additionalProperties: false
    }
  end
end

defmodule BlockScoutWeb.Schemas.API.V2.Block do
  @moduledoc """
  This module defines the schema for the Block struct.
  """
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.{Block.ChainTypeCustomizations, Block.Common}

  OpenApiSpex.schema(
    Common.schema()
    |> ChainTypeCustomizations.chain_type_fields()
  )
end
