defmodule BlockScoutWeb.Schemas.API.V2.InternalTransaction do
  @moduledoc """
  This module defines the schema for the InternalTransaction struct.
  """
  require OpenApiSpex

  alias OpenApiSpex.Schema
  alias BlockScoutWeb.Schemas.API.V2.{Address, General}

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
        description: "Type of the internal transaction (call, create, etc.)"
      },
      transaction_hash: General.FullHash,
      transaction_index: %Schema{
        type: :integer,
        nullable: false,
        description: "The index of the parent transaction inside the block."
      },
      from: Address,
      to: Address,
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
      gas_limit: General.IntegerStringNullable,
      block_index: %Schema{
        type: :integer,
        description: "The index of this internal transaction inside the block.",
        nullable: false
      }
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
      :gas_limit,
      :block_index
    ]
  })
end
