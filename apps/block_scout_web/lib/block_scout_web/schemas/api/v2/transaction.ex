defmodule BlockScoutWeb.Schemas.API.V2.Transaction.ChainTypeCustomizations do
  @moduledoc false
  alias BlockScoutWeb.API.V2.ZkSyncView
  alias BlockScoutWeb.Schemas.API.V2.{Address, General, Token}
  alias BlockScoutWeb.Schemas.API.V2.Transaction.Fee
  alias BlockScoutWeb.Schemas.Helper
  alias OpenApiSpex.Schema

  @zksync_schema %Schema{
    type: :object,
    nullable: false,
    properties: %{
      batch_number: %Schema{type: :integer, nullable: true},
      status: %Schema{
        type: :string,
        enum: ZkSyncView.batch_status_enum(),
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
    ],
    additionalProperties: false
  }

  @arbitrum_commitment_transaction_schema %Schema{
    type: :object,
    nullable: false,
    properties: %{
      hash: General.FullHashNullable,
      timestamp: General.TimestampNullable,
      status: %Schema{type: :string, enum: ["unfinalized", "finalized"], nullable: true}
    },
    required: [:hash, :timestamp, :status],
    additionalProperties: false
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
        },
        additionalProperties: false
      },
      gas_used_for_l1: General.IntegerString,
      gas_used_for_l2: General.IntegerString,
      poster_fee: General.IntegerString,
      network_fee: General.IntegerString
    },
    required: [:gas_used_for_l1, :gas_used_for_l2, :poster_fee, :network_fee],
    additionalProperties: false
  }

  @optimism_withdrawal_schema %Schema{
    type: :object,
    nullable: false,
    properties: %{
      nonce: %Schema{type: :integer},
      status: %Schema{type: :string, nullable: false},
      l1_transaction_hash: General.FullHashNullable
    },
    required: [:nonce, :status, :l1_transaction_hash],
    additionalProperties: false
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
    ],
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
  # credo:disable-for-next-line
  def chain_type_fields(schema) do
    case Application.get_env(:explorer, :chain_type) do
      :polygon_zkevm ->
        schema
        |> Helper.extend_schema(
          properties: %{
            zkevm_batch_number: %Schema{type: :integer, nullable: true},
            zkevm_sequence_hash: General.FullHash,
            zkevm_verify_hash: General.FullHash,
            zkevm_status: %Schema{
              type: :string,
              enum: ["Confirmed by Sequencer", "L1 Confirmed"],
              nullable: false
            }
          }
        )

      :zksync ->
        schema |> Helper.extend_schema(properties: %{zksync: @zksync_schema})

      :arbitrum ->
        schema |> Helper.extend_schema(properties: %{arbitrum: @arbitrum_schema})

      :optimism ->
        schema
        |> Helper.extend_schema(
          properties: %{
            l1_fee: General.IntegerString,
            l1_fee_scalar: General.IntegerString,
            l1_gas_price: General.IntegerString,
            l1_gas_used: General.IntegerString,
            op_withdrawals: %Schema{
              type: :array,
              items: @optimism_withdrawal_schema,
              nullable: false
            },
            op_interop: %Schema{
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
              required: [:nonce, :status, :sender_address_hash, :target_address_hash, :payload],
              additionalProperties: false
            },
            operator_fee: General.IntegerString
          }
        )

      :scroll ->
        schema |> Helper.extend_schema(properties: %{scroll: @scroll_schema})

      :suave ->
        schema
        |> Helper.extend_schema(
          properties: %{
            allowed_peekers: %Schema{type: :array, items: General.AddressHash, nullable: false},
            execution_node: Address,
            wrapped: %Schema{
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
              },
              additionalProperties: false
            }
          }
        )

      :stability ->
        schema
        |> Helper.extend_schema(
          properties: %{
            stability_fee: %Schema{
              type: :object,
              nullable: false,
              properties: %{
                token: Token,
                validator_address: Address,
                dapp_address: Address,
                total_fee: General.IntegerString,
                dapp_fee: General.IntegerString,
                validator_fee: General.IntegerString
              },
              required: [:token, :validator_address, :dapp_address, :total_fee, :dapp_fee, :validator_fee],
              additionalProperties: false
            }
          }
        )

      :ethereum ->
        schema
        |> Helper.extend_schema(
          properties: %{
            max_fee_per_blob_gas: General.IntegerString,
            blob_versioned_hashes: %Schema{type: :array, items: General.FullHash, nullable: false},
            blob_gas_used: General.IntegerString,
            blob_gas_price: General.IntegerString,
            burnt_blob_fee: General.IntegerString
          }
        )

      :celo ->
        schema
        |> Helper.extend_schema(
          properties: %{
            celo: %Schema{
              type: :object,
              nullable: false,
              properties: %{gas_token: %Schema{allOf: [Token], nullable: true}},
              required: [:gas_token],
              additionalProperties: false
            }
          },
          required: [:celo]
        )

      :zilliqa ->
        schema
        |> Helper.extend_schema(
          properties: %{
            zilliqa: %Schema{
              type: :object,
              nullable: false,
              properties: %{
                is_scilla: %Schema{type: :boolean, nullable: false}
              },
              required: [:is_scilla],
              additionalProperties: false
            }
          },
          required: [:zilliqa]
        )

      _ ->
        schema
    end
  end
end

defmodule BlockScoutWeb.Schemas.API.V2.Transaction do
  @moduledoc """
  This module defines the schema for the Transaction struct.
  """
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.{Address, General, SignedAuthorization, TokenTransfer}
  alias BlockScoutWeb.Schemas.API.V2.Transaction.{ChainTypeCustomizations, Fee}
  alias Explorer.Chain.TransactionAction
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(
    %{
      type: :object,
      properties: %{
        hash: General.FullHash,
        result: %Schema{
          anyOf: [
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
        created_contract: %Schema{allOf: [Address], nullable: true},
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
          maxItems: 2
        },
        value: General.IntegerString,
        fee: Fee,
        gas_price: General.IntegerStringNullable,
        type: %Schema{
          type: :integer,
          nullable: true
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
              properties: %{raw: %Schema{anyOf: [General.HexString, %Schema{type: :string}], nullable: true}},
              required: [:raw],
              nullable: false,
              additionalProperties: false
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
                enum: TransactionAction.supported_protocols(),
                nullable: false
              },
              type: %Schema{
                type: :string,
                enum: TransactionAction.supported_types(),
                nullable: false
              },
              data: %Schema{
                type: :object,
                description: "Transaction action details (json formatted)",
                nullable: false
              }
            },
            additionalProperties: false
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
        authorization_list: %Schema{type: :array, items: SignedAuthorization, nullable: true},
        is_pending_update: %Schema{type: :boolean, nullable: true}
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
        :authorization_list,
        :is_pending_update
      ],
      additionalProperties: false
    }
    |> ChainTypeCustomizations.chain_type_fields()
  )
end
