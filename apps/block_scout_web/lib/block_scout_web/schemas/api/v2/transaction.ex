defmodule BlockScoutWeb.Schemas.API.V2.Transaction.ChainTypeCustomizations do
  @moduledoc false
  alias OpenApiSpex.Schema
  alias BlockScoutWeb.Schemas.API.V2.Transaction.Fee

  @polygon_edge_deposit_withdrawal_schema %Schema{type: :object, nullable: true}

  @zksync_schema %Schema{
    type: :object,
    nullable: false,
    properties: %{
      batch_number: %Schema{type: :integer, nullable: true},
      status: %Schema{
        type: :string,
        enum: ["Executed on L1", "Validated on L1", "Sent to L1", "Sealed on L2", "Processed on L2"],
        nullable: true
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

  @arbitrum_commitment_transaction_schema %Schema{
    type: :object,
    nullable: false,
    properties: %{
      hash: General.FullHashNullable,
      timestamp: General.TimestampNullable,
      status: %Schema{type: :string, enum: ["unfinalized", "finalized"], nullable: true}
    },
    required: [:hash, :timestamp, :status]
  }

  @arbitrum_schema %Schema{
    type: :object,
    nullable: false,
    properties: %{
      batch_data_container: %Schema{type: :string, nullable: true},
      batch_number: %Schema{type: :integer, nullable: true},
      status: %Schema{
        type: :string,
        enum: ["Confirmed on base", "Sent to base", "Sealed on rollup", "Processed on rollup"],
        nullable: false
      },
      commitment_transaction: @arbitrum_commitment_transaction_schema,
      confirmation_transaction: @arbitrum_commitment_transaction_schema,
      contains_message: %Schema{type: :string, enum: ["incoming", "outcoming"], nullable: true},
      message_related_info: %Schema{
        type: :object,
        nullable: false,
        properties: %{
          message_id: %Schema{type: :integer, nullable: false},
          associated_l1_transaction_hash: General.FullHashNullable,
          message_status: %Schema{
            type: :string,
            enum: [
              "Syncing with base layer",
              "Relayed",
              "Settlement pending",
              "Waiting for confirmation",
              "Ready for relay"
            ],
            nullable: false
          }
        }
      },
      gas_used_for_l1: General.IntegerString,
      gas_used_for_l2: General.IntegerString,
      poster_fee: General.IntegerString,
      network_fee: General.IntegerString
    },
    required: [:gas_used_for_l1, :gas_used_for_l2, :poster_fee, :network_fee]
  }

  @optimism_withdrawal_schema %Schema{
    type: :object,
    nullable: false,
    properties: %{
      nonce: %Schema{type: :integer},
      status: %Schema{type: :string, nullable: false},
      l1_transaction_hash: General.FullHashNullable
    },
    required: [:nonce, :status, :l1_transaction_hash]
  }

  @scroll_schema %Schema{
    type: :object,
    nullable: false,
    properties: %{
      l1_fee_scalar: %Schema{type: :integer, nullable: true},
      l1_fee_commit_scalar: %Schema{type: :integer, nullable: true},
      l1_fee_blob_scalar: %Schema{type: :integer, nullable: true},
      l1_fee_overhead: %Schema{type: :integer, nullable: true},
      l1_base_fee: %Schema{type: :integer, nullable: true},
      l1_blob_base_fee: %Schema{type: :integer, nullable: true},
      l1_gas_used: %Schema{type: :integer, nullable: true},
      l2_fee: Fee,
      l2_block_status: %Schema{
        type: :string,
        enum: ["Committed", "Finalized", "Confirmed by Sequencer"],
        nullable: false
      },
      l1_fee: General.IntegerString,
      queue_index: %Schema{type: :integer, nullable: false}
    },
    required: [
      :l1_fee_scalar,
      :l1_fee_commit_scalar,
      :l1_fee_blob_scalar,
      :l1_fee_overhead,
      :l1_base_fee,
      :l1_blob_base_fee,
      :l1_gas_used,
      :l2_fee,
      :l2_block_status
    ]
  }

  def chain_type_fields(schema) do
    case Application.get_env(:explorer, :chain_type) do
      :polygon_edge ->
        schema
        |> put_in([:properties, :polygon_edge_deposit], @polygon_edge_deposit_withdrawal_schema)
        |> put_in([:properties, :polygon_edge_withdrawal], @polygon_edge_deposit_withdrawal_schema)
        |> update_in([:required], &([:polygon_edge_deposit, :polygon_edge_withdrawal] ++ &1))

      :polygon_zkevm ->
        schema
        |> put_in([:properties, :zkevm_batch_number], %Schema{type: :integer, nullable: true})
        |> put_in([:properties, :zkevm_sequence_hash], General.FullHash)
        |> put_in([:properties, :zkevm_verify_hash], General.FullHash)
        |> put_in([:properties, :zkevm_status], %Schema{
          type: :string,
          enum: ["Confirmed by Sequencer", "L1 Confirmed"],
          nullable: false
        })
        |> update_in([:required], &[:zkevm_status | &1])

      :zksync ->
        schema
        |> put_in([:properties, :zksync], @zksync_schema)
        |> update_in([:required], &[:zksync | &1])

      :arbitrum ->
        schema
        |> put_in([:properties, :arbitrum], @arbitrum_schema)
        |> update_in([:required], &[:arbitrum | &1])

      :optimism ->
        schema
        |> put_in([:properties, :l1_fee], General.IntegerString)
        |> put_in([:properties, :l1_fee_scalar], General.IntegerString)
        |> put_in([:properties, :l1_gas_price], General.IntegerString)
        |> put_in([:properties, :l1_gas_used], General.IntegerString)
        |> put_in([:properties, :op_withdrawals], %Schema{
          type: :array,
          items: @optimism_withdrawal_schema,
          nullable: false
        })
        |> put_in([:properties, :op_interop], %Schema{
          type: :object,
          nullable: false,
          properties: %{
            nonce: %Schema{type: :integer},
            status: %Schema{type: :string, nullable: false, enum: ["Sent", "Relayed", "Failed"]},
            sender_address_hash: General.AddressHashNullable,
            target_address_hash: General.AddressHashNullable,
            payload: General.HexString,
            relay_chain: %Schema{type: :object, nullable: true},
            relay_transaction_hash: General.FullHashNullable,
            init_chain: %Schema{type: :object, nullable: true},
            init_transaction_hash: General.FullHashNullable
          },
          required: [:nonce, :status, :sender_address_hash, :target_address_hash, :payload]
        })

      :scroll ->
        schema
        |> put_in([:properties, :scroll], @scroll_schema)
        |> update_in([:required], &[:scroll | &1])

      :suave ->
        schema
        |> put_in([:properties, :allowed_peekers], %Schema{type: :array, items: General.AddressHash, nullable: false})
        |> put_in([:properties, :execution_node], Address)
        |> put_in([:properties, :wrapped], %Schema{
          type: :object,
          nullable: false,
          properties: %{
            type: %Schema{type: :integer},
            nonce: %Schema{type: :integer, nullable: true},
            to: Address,
            gas_limit: General.IntegerStringNullable,
            gas_price: General.IntegerStringNullable,
            fee: Fee,
            max_priority_fee_per_gas: General.IntegerStringNullable,
            max_fee_per_gas: General.IntegerStringNullable,
            value: General.IntegerStringNullable,
            hash: General.FullHash,
            method: General.MethodNameNullable,
            decoded_input: %Schema{allOf: [General.DecodedInput], nullable: true},
            raw_input: General.HexString
          }
        })

      :stability ->
        schema
        # TODO: add stability fields
    end
  end
end

defmodule BlockScoutWeb.Schemas.API.V2.Transaction do
  @moduledoc """
  This module defines the schema for the Transaction struct.
  """
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.General
  alias BlockScoutWeb.Schemas.API.V2.{Address, SignedAuthorization, TokenTransfer}
  alias OpenApiSpex.Schema
  alias BlockScoutWeb.Schemas.API.V2.Transaction.{ChainTypeCustomizations, Fee}

  OpenApiSpex.schema(
    %{
      type: :object,
      properties: %{
        hash: General.FullHash,
        result: %Schema{
          oneOf: [
            %Schema{
              type: :string,
              enum: ["pending", "awaiting_internal_transactions", "success", "dropped/replaced"]
            },
            %Schema{
              type: :string,
              description: "Error message",
              example: "out of gas"
            }
          ],
          nullable: false
        },
        status: %Schema{
          type: :string,
          enum: ["ok", "error"],
          nullable: true
        },
        block_number: %Schema{
          type: :integer,
          nullable: true
        },
        timestamp: General.TimestampNullable,
        from: Address,
        to: Address,
        created_contract: Address,
        confirmations: %Schema{
          type: :integer,
          minimum: 0
        },
        confirmation_duration: %Schema{
          type: :array,
          items: %Schema{
            type: :integer,
            minimum: 0,
            description: "Duration in milliseconds"
          },
          description:
            "Array of time intervals in milliseconds. Can be empty [] (no info), single value [interval] (means that the transaction was confirmed within {interval} milliseconds), or two values [short_interval, long_interval] (means that the transaction's confirmation took from {short_interval} to {long_interval} milliseconds)",
          example: [1000, 2000],
          maxLength: 2
        },
        value: General.IntegerString,
        fee: Fee,
        gas_price: General.IntegerStringNullable,
        type: %Schema{
          type: :integer,
          nullable: false
        },
        gas_used: General.IntegerStringNullable,
        gas_limit: General.IntegerString,
        max_fee_per_gas: General.IntegerStringNullable,
        max_priority_fee_per_gas: General.IntegerStringNullable,
        base_fee_per_gas: General.IntegerStringNullable,
        priority_fee: General.IntegerStringNullable,
        transaction_burnt_fee: General.IntegerStringNullable,
        nonce: %Schema{
          type: :integer,
          nullable: false,
          minimum: 0
        },
        position: %Schema{
          type: :integer,
          nullable: true,
          minimum: 0
        },
        revert_reason: %Schema{
          oneOf: [
            General.DecodedInput,
            %Schema{
              type: :object,
              properties: %{raw: %Schema{oneOf: [General.HexString, %Schema{type: :string}], nullable: true}},
              required: [:raw],
              nullable: false
            }
          ],
          nullable: true
        },
        raw_input: General.HexString,
        decoded_input: %Schema{allOf: [General.DecodedInput], nullable: true},
        token_transfers: %Schema{type: :array, items: TokenTransfer, nullable: true},
        token_transfers_overflow: %Schema{type: :boolean, nullable: true},
        actions: %Schema{
          type: :array,
          items: %Schema{
            type: :object,
            required: [:protocol, :type, :data],
            properties: %{
              protocol: %Schema{
                type: :string,
                enum: [:uniswap_v3, :opensea_v1_1, :wrapping, :approval, :zkbob, :aave_v3],
                nullable: false
              },
              type: %Schema{
                type: :string,
                enum: [
                  :mint_nft,
                  :mint,
                  :burn,
                  :collect,
                  :swap,
                  :sale,
                  :cancel,
                  :transfer,
                  :wrap,
                  :unwrap,
                  :approve,
                  :revoke,
                  :withdraw,
                  :deposit,
                  :borrow,
                  :supply,
                  :repay,
                  :flash_loan,
                  :enable_collateral,
                  :disable_collateral,
                  :liquidation_call
                ],
                nullable: false
              },
              data: %Schema{
                type: :object,
                description: "Transaction action details (json formatted)",
                nullable: false
              }
            }
          },
          nullable: true
        },
        exchange_rate: General.FloatStringNullable,
        historic_exchange_rate: General.FloatStringNullable,
        method: General.MethodNameNullable,
        transaction_types: %Schema{
          type: :array,
          items: %Schema{
            type: :string,
            enum: [
              "coin_transfer",
              "contract_call",
              "contract_creation",
              "rootstock_bridge",
              "rootstock_remasc",
              "token_creation",
              "token_transfer",
              "blob_transaction",
              "set_code_transaction"
            ]
          }
        },
        transaction_tag: %Schema{
          type: :string,
          nullable: true,
          example: "personal",
          description: "Transaction tag set in My Account"
        },
        has_error_in_internal_transactions: %Schema{type: :boolean, nullable: true},
        authorization_list: %Schema{type: :array, items: SignedAuthorization, nullable: true}
      },
      required: [
        :hash,
        :result,
        :status,
        :block_number,
        :timestamp,
        :from,
        :to,
        :created_contract,
        :confirmations,
        :confirmation_duration,
        :value,
        :fee,
        :gas_price,
        :type,
        :gas_used,
        :gas_limit,
        :max_fee_per_gas,
        :max_priority_fee_per_gas,
        :base_fee_per_gas,
        :priority_fee,
        :transaction_burnt_fee,
        :nonce,
        :position,
        :revert_reason,
        :raw_input,
        :decoded_input,
        :token_transfers,
        :token_transfers_overflow,
        :actions,
        :exchange_rate,
        :historic_exchange_rate,
        :method,
        :transaction_types,
        :transaction_tag,
        :has_error_in_internal_transactions,
        :authorization_list
      ]
    }
    |> ChainTypeCustomizations.chain_type_fields()
  )
end

defmodule BlockScoutWeb.Schemas.API.V2.Transaction.Fee do
  @moduledoc """
  This module defines the schema for the Transaction fee.
  """
  require OpenApiSpex

  OpenApiSpex.schema(%{
    type: :object,
    required: [:type, :value],
    properties: %{
      type: %Schema{
        type: :string,
        enum: ["maximum", "actual"]
      },
      value: General.IntegerStringNullable
    }
  })
end
