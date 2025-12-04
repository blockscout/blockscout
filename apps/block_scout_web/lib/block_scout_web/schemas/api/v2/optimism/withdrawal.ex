defmodule BlockScoutWeb.Schemas.API.V2.Optimism.Withdrawal do
  @moduledoc """
  This module defines the schema for the Optimism Withdrawal struct.
  """
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.{AddressNullable, General}
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    description: "Optimism Withdrawal struct.",
    type: :object,
    properties: %{
      challenge_period_end: General.TimestampNullable,
      from: AddressNullable,
      l1_transaction_hash: General.FullHashNullable,
      l2_timestamp: General.TimestampNullable,
      l2_transaction_hash: General.FullHash,
      msg_data: General.HexStringNullable,
      msg_gas_limit: General.IntegerStringNullable,
      msg_nonce: %Schema{type: :integer},
      msg_nonce_raw: General.IntegerString,
      msg_nonce_version: %Schema{type: :integer},
      msg_sender_address_hash: General.FullHashNullable,
      msg_target_address_hash: General.FullHashNullable,
      msg_value: General.IntegerStringNullable,
      portal_contract_address_hash: General.AddressHashNullable,
      status: %Schema{
        type: :string,
        enum: [
          "Waiting for state root",
          "Ready to prove",
          "Waiting a game to resolve",
          "In challenge period",
          "Ready for relay",
          "Proven",
          "Relayed"
        ],
        nullable: false
      }
    },
    required: [
      :challenge_period_end,
      :from,
      :l1_transaction_hash,
      :l2_timestamp,
      :l2_transaction_hash,
      :msg_data,
      :msg_gas_limit,
      :msg_nonce,
      :msg_nonce_raw,
      :msg_nonce_version,
      :msg_sender_address_hash,
      :msg_target_address_hash,
      :msg_value,
      :portal_contract_address_hash,
      :status
    ],
    additionalProperties: false
  })
end
