defmodule BlockScoutWeb.Schemas.API.V2.Proxy.AccountAbstraction.Account do
  @moduledoc """
  This module defines the schema for the Account struct.
  """
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.{Address, AddressNullable, General}
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    description: "Account struct.",
    type: :object,
    properties: %{
      address: Address,
      creation_op_hash: General.FullHashNullable,
      creation_transaction_hash: General.FullHashNullable,
      creation_timestamp: General.TimestampNullable,
      factory: AddressNullable,
      total_ops: %Schema{type: :integer, nullable: false, minimum: 0}
    },
    required: [
      :address,
      :creation_op_hash,
      :creation_transaction_hash,
      :creation_timestamp,
      :factory,
      :total_ops
    ],
    nullable: false,
    additionalProperties: false
  })
end
