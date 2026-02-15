defmodule BlockScoutWeb.Schemas.API.V2.Proxy.AccountAbstraction.UserOperation do
  @moduledoc """
  This module defines the schema for the UserOperation struct.
  """
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.{Address, AddressNullable, General}
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    description: "UserOperation struct.",
    type: :object,
    properties: %{
      hash: General.FullHash,
      sender: Address,
      nonce: General.FullHash,
      call_data: General.HexString,
      call_gas_limit: General.IntegerString,
      verification_gas_limit: General.IntegerString,
      pre_verification_gas: General.IntegerString,
      max_fee_per_gas: General.IntegerString,
      max_priority_fee_per_gas: General.IntegerString,
      signature: General.HexString,
      raw: %Schema{
        description: "Raw user operation data.",
        anyOf: [
          %Schema{
            description: "Raw user operation data v0.6.",
            type: :object,
            properties: %{
              sender: General.AddressHash,
              nonce: General.IntegerString,
              init_code: General.HexString,
              call_data: General.HexString,
              call_gas_limit: General.IntegerString,
              verification_gas_limit: General.IntegerString,
              pre_verification_gas: General.IntegerString,
              max_fee_per_gas: General.IntegerString,
              max_priority_fee_per_gas: General.IntegerString,
              paymaster_and_data: General.HexString,
              signature: General.HexString
            },
            required: [
              :sender,
              :nonce,
              :init_code,
              :call_data,
              :call_gas_limit,
              :verification_gas_limit,
              :pre_verification_gas,
              :max_fee_per_gas,
              :max_priority_fee_per_gas,
              :paymaster_and_data,
              :signature
            ],
            nullable: false,
            additionalProperties: false
          },
          %Schema{
            description: "Raw user operation data v0.7-v0.9.",
            type: :object,
            properties: %{
              sender: General.AddressHash,
              nonce: General.IntegerString,
              init_code: General.HexString,
              call_data: General.HexString,
              account_gas_limits: General.FullHash,
              pre_verification_gas: General.IntegerString,
              gas_fees: General.FullHash,
              paymaster_and_data: General.HexString,
              signature: General.HexString
            },
            required: [
              :sender,
              :nonce,
              :init_code,
              :call_data,
              :account_gas_limits,
              :pre_verification_gas,
              :gas_fees,
              :paymaster_and_data,
              :signature
            ],
            nullable: false,
            additionalProperties: false
          }
        ]
      },
      aggregator: General.AddressHashNullable,
      aggregator_signature: General.HexStringNullable,
      entry_point: Address,
      entry_point_version: %Schema{
        type: :string,
        enum: ["v0.6", "v0.7", "v0.8", "v0.9"],
        nullable: false
      },
      transaction_hash: General.FullHash,
      block_number: General.IntegerString,
      block_hash: General.FullHash,
      bundler: Address,
      bundle_index: %Schema{type: :integer, nullable: false},
      index: %Schema{type: :integer, nullable: false},
      factory: AddressNullable,
      paymaster: AddressNullable,
      status: %Schema{type: :boolean, nullable: false},
      revert_reason: General.HexStringNullable,
      gas: General.IntegerString,
      gas_price: General.IntegerString,
      gas_used: General.IntegerString,
      sponsor_type: %Schema{
        type: :string,
        enum: ["wallet_deposit", "wallet_balance", "paymaster_sponsor", "paymaster_hybrid"],
        nullable: false
      },
      user_logs_start_index: %Schema{type: :integer, nullable: false},
      user_logs_count: %Schema{type: :integer, nullable: false},
      fee: General.IntegerString,
      consensus: %Schema{type: :boolean, nullable: true},
      timestamp: General.TimestampNullable,
      execute_target: AddressNullable,
      execute_call_data: General.HexStringNullable,
      decoded_call_data: %Schema{allOf: [General.DecodedInput], nullable: true},
      decoded_execute_call_data: %Schema{allOf: [General.DecodedInput], nullable: true}
    },
    required: [
      :hash,
      :sender,
      :nonce,
      :call_data,
      :call_gas_limit,
      :verification_gas_limit,
      :pre_verification_gas,
      :max_fee_per_gas,
      :max_priority_fee_per_gas,
      :signature,
      :raw,
      :aggregator,
      :aggregator_signature,
      :entry_point,
      :entry_point_version,
      :transaction_hash,
      :block_number,
      :block_hash,
      :bundler,
      :bundle_index,
      :index,
      :factory,
      :paymaster,
      :status,
      :revert_reason,
      :gas,
      :gas_price,
      :gas_used,
      :sponsor_type,
      :user_logs_start_index,
      :user_logs_count,
      :fee,
      :consensus,
      :timestamp,
      :execute_target,
      :execute_call_data,
      :decoded_call_data,
      :decoded_execute_call_data
    ],
    nullable: false,
    additionalProperties: false
  })
end
