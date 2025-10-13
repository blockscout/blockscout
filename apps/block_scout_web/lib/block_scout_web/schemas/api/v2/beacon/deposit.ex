defmodule BlockScoutWeb.Schemas.API.V2.Beacon.Deposit do
  @moduledoc """
  This module defines the schema for the Beacon.Deposit struct.
  """
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.{Address, Beacon.Deposit.Status, General}
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    type: :object,
    properties: %{
      index: %Schema{type: :integer, nullable: false},
      transaction_hash: General.FullHash,
      block_hash: General.FullHash,
      block_number: %Schema{type: :integer, nullable: false},
      block_timestamp: General.Timestamp,
      pubkey: %Schema{type: :string, pattern: ~r"^0x([A-Fa-f0-9]{96})$", nullable: false},
      withdrawal_credentials: %Schema{type: :string, pattern: General.full_hash_pattern(), nullable: false},
      withdrawal_address: %Schema{allOf: [Address], nullable: true},
      amount: General.IntegerString,
      signature: %Schema{type: :string, pattern: ~r"^0x([A-Fa-f0-9]{192})$", nullable: false},
      status: Status,
      from_address: Address
    },
    required: [
      :index,
      :transaction_hash,
      :block_hash,
      :block_number,
      :block_timestamp,
      :pubkey,
      :withdrawal_credentials,
      :amount,
      :signature,
      :status,
      :from_address
    ],
    additionalProperties: false
  })
end
