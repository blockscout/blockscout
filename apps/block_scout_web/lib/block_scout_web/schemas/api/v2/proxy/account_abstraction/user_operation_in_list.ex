defmodule BlockScoutWeb.Schemas.API.V2.Proxy.AccountAbstraction.UserOperationInList do
  @moduledoc """
  This module defines the schema for the UserOperationInList struct.
  """
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.{Address, General}
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    description: "UserOperationInList struct.",
    type: :object,
    properties: %{
      hash: General.FullHash,
      address: Address,
      entry_point: Address,
      entry_point_version: %Schema{
        type: :string,
        enum: ["v0.6", "v0.7", "v0.8", "v0.9"],
        nullable: false
      },
      transaction_hash: General.FullHash,
      block_number: General.IntegerString,
      status: %Schema{type: :boolean, nullable: false},
      fee: General.IntegerString,
      timestamp: General.TimestampNullable
    },
    required: [
      :hash,
      :address,
      :entry_point,
      :entry_point_version,
      :transaction_hash,
      :block_number,
      :status,
      :fee,
      :timestamp
    ],
    nullable: false,
    additionalProperties: false
  })
end
