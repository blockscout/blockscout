# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule BlockScoutWeb.Schemas.API.V2.InternalTransaction do
  @moduledoc """
  This module defines the schema for the InternalTransaction struct.
  """
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.{Address, General}
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    type: :object,
    properties: %{
      error: %Schema{
        type: :string,
        nullable: true
      },
      success: %Schema{
        type: :boolean,
        nullable: false
      },
      type: %Schema{
        type: :string,
        nullable: false,
        # Rendered as `call_type || type` (CallType ∪ Type values); `invalid` is Arbitrum-only.
        enum: [
          "call",
          "callcode",
          "delegatecall",
          "staticcall",
          "create",
          "create2",
          "reward",
          "selfdestruct",
          "stop",
          "invalid"
        ],
        description: "Type of the internal transaction (call, create, etc.)"
      },
      transaction_hash: General.FullHash,
      transaction_index: %Schema{
        type: :integer,
        nullable: false,
        description: "The index of the parent transaction inside the block."
      },
      from: Address,
      to: %Schema{allOf: [Address], nullable: true},
      created_contract: %Schema{allOf: [Address], nullable: true},
      value: General.IntegerString,
      block_number: %Schema{
        type: :integer,
        nullable: false
      },
      timestamp: General.Timestamp,
      index: %Schema{
        type: :integer,
        description: "The index of this internal transaction inside the transaction.",
        nullable: false
      },
      gas_limit: General.IntegerStringNullable
    },
    required: [
      :error,
      :success,
      :type,
      :transaction_hash,
      :transaction_index,
      :from,
      :to,
      :created_contract,
      :value,
      :block_number,
      :timestamp,
      :index,
      :gas_limit
    ],
    additionalProperties: false
  })
end
