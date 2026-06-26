# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule BlockScoutWeb.Schemas.API.V2.Optimism.TransactionWithdrawal do
  @moduledoc """
  Schema for an L2->L1 withdrawal message initiated by an Optimism transaction
  (an item of `Transaction.op_withdrawals`).

  Matches the map built in `BlockScoutWeb.API.V2.OptimismView.add_optimism_fields/2`.
  """
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.General
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "OptimismTransactionWithdrawal",
    description: "L2->L1 withdrawal message initiated by an Optimism transaction",
    type: :object,
    nullable: false,
    properties: %{
      nonce: %Schema{type: :integer},
      status: %Schema{type: :string, nullable: false},
      l1_transaction_hash: General.FullHashNullable,
      portal_contract_address_hash: General.AddressHashNullable,
      msg_nonce_raw: General.IntegerString,
      msg_sender_address_hash: General.FullHashNullable,
      msg_target_address_hash: General.FullHashNullable,
      msg_value: General.IntegerStringNullable,
      msg_gas_limit: General.IntegerStringNullable,
      msg_data: General.HexDataNullable
    },
    required: [
      :nonce,
      :status,
      :l1_transaction_hash,
      :portal_contract_address_hash,
      :msg_nonce_raw,
      :msg_sender_address_hash,
      :msg_target_address_hash,
      :msg_value,
      :msg_gas_limit,
      :msg_data
    ],
    additionalProperties: false
  })
end
