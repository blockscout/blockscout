defmodule BlockScoutWeb.Schemas.API.V2.Block.ChainTypeCustomizations do
  @moduledoc false
  alias BlockScoutWeb.API.V2.ZkSyncView
  alias BlockScoutWeb.Schemas.API.V2.{Address, General, Token}
  alias OpenApiSpex.Schema

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
    ]
  }

  @arbitrum_schema %Schema{
    type: :object,
    nullable: false,
    properties: %{
      batch_number: %Schema{type: :integer, nullable: true},
      batch_data_container: %Schema{
        type: :string,
        nullable: true,
        enum: ["in_blob4844", "in_calldata", "in_celestia", "in_anytrust"]
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
    required: [:batch_number, :status, :commitment_transaction, :confirmation_transaction]
  }

  @blob4844_schema %Schema{
    type: :object,
    nullable: false,
    properties: %{
      hash: General.FullHashNullable,
      l1_transaction_hash: General.FullHashNullable,
      l1_timestamp: General.TimestampNullable
    },
    required: [:hash, :l1_transaction_hash, :l1_timestamp]
  }

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
    required: [:height, :namespace, :commitment, :l1_transaction_hash, :l1_timestamp]
  }

  @optimism_schema %Schema{
    type: :object,
    nullable: false,
    properties: %{
      number: %Schema{type: :integer, nullable: true},
      l1_timestamp: General.TimestampNullable,
      l1_transaction_hashes: %Schema{type: :array, items: General.FullHash, nullable: false},
      batch_data_container: %Schema{type: :string, nullable: false, enum: ["in_blob4844", "in_celestia", "in_calldata"]},
      blobs: %Schema{type: :array, items: %Schema{anyOf: [@blob4844_schema, @celestia_schema]}, nullable: false}
    },
    required: [:number, :l1_timestamp, :l1_transaction_hashes, :batch_data_container]
  }

  @celo_schema %Schema{
    type: :object,
    nullable: false,
    properties: %{
      is_epoch_block: %Schema{type: :boolean, nullable: false},
      epoch_number: %Schema{type: :integer, nullable: false},
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
              required: [:address, :amount, :percentage]
            },
            nullable: false
          }
        },
        required: [:recipient, :amount, :token, :breakdown]
      }
    },
    required: [:is_epoch_block, :epoch_number]
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
        required: [:view, :signature, :signers]
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
              required: [:view, :signature, :proposed_by_validator_index, :signers]
            },
            nullable: false
          }
        },
        required: [:view, :signature, :signers, :nested_quorum_certificates]
      }
    },
    required: [:view]
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
      :rsk ->
        schema
        |> put_in([:properties, :minimum_gas_price], General.IntegerString)
        |> put_in([:properties, :bitcoin_merged_mining_header], General.HexString)
        |> put_in([:properties, :bitcoin_merged_mining_coinbase_transaction], General.HexString)
        |> put_in([:properties, :bitcoin_merged_mining_merkle_proof], General.HexString)
        |> put_in([:properties, :hash_for_merged_mining], General.FullHash)

      :optimism ->
        schema
        |> put_in([:properties, :optimism], @optimism_schema)

      :zksync ->
        schema
        |> put_in([:properties, :zksync], @zksync_schema)

      :arbitrum ->
        schema
        |> put_in([:properties, :arbitrum], @arbitrum_schema)

      :ethereum ->
        schema
        |> put_in([:properties, :blob_transactions_count], %Schema{type: :integer, nullable: false})
        |> put_in([:properties, :blob_gas_used], General.IntegerStringNullable)
        |> put_in([:properties, :excess_blob_gas], General.IntegerStringNullable)
        |> put_in([:properties, :blob_gas_price], General.IntegerString)
        |> put_in([:properties, :burnt_blob_fees], General.IntegerString)
        |> update_in([:required], &([:blob_transactions_count, :blob_gas_used, :excess_blob_gas] ++ &1))

      :celo ->
        schema
        |> put_in([:properties, :celo], @celo_schema)
        |> update_in([:required], &[:celo | &1])

      :zilliqa ->
        schema
        |> put_in([:properties, :zilliqa], @zilliqa_schema)

      _ ->
        schema
    end
  end
end

defmodule BlockScoutWeb.Schemas.API.V2.Block do
  @moduledoc """
  This module defines the schema for the Block struct.
  """
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.{Address, Block.ChainTypeCustomizations, General}
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(
    %{
      type: :object,
      properties: %{
        height: %Schema{type: :integer, nullable: false},
        timestamp: General.Timestamp,
        transactions_count: %Schema{type: :integer, nullable: false},
        internal_transactions_count: %Schema{type: :integer, nullable: true},
        miner: Address,
        size: %Schema{type: :integer, nullable: false},
        hash: General.FullHash,
        parent_hash: General.FullHash,
        difficulty: General.IntegerString,
        total_difficulty: General.IntegerString,
        gas_used: General.IntegerString,
        gas_limit: General.IntegerString,
        nonce: General.HexStringNullable,
        base_fee_per_gas: General.IntegerStringNullable,
        burnt_fees: General.IntegerStringNullable,
        priority_fee: General.IntegerStringNullable,
        uncles_hashes: %Schema{
          type: :array,
          items: %Schema{type: :object, properties: %{hash: General.FullHash}, required: [:hash], nullable: false},
          nullable: false
        },
        rewards: %Schema{
          type: :array,
          items: %Schema{
            type: :object,
            properties: %{
              type: %Schema{type: :string, nullable: false},
              reward: General.IntegerString
            },
            required: [:type, :reward]
          },
          nullable: false
        },
        gas_target_percentage: %Schema{type: :number, format: :float, nullable: false},
        gas_used_percentage: %Schema{type: :number, format: :float, nullable: false},
        burnt_fees_percentage: %Schema{type: :number, format: :float, nullable: true},
        type: %Schema{type: :string, nullable: false, enum: ["block", "uncle", "reorg"]},
        transaction_fees: General.IntegerString,
        withdrawals_count: %Schema{type: :integer, nullable: true}
      },
      required: [
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
        :withdrawals_count
      ]
    }
    |> ChainTypeCustomizations.chain_type_fields()
  )
end
