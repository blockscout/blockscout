defmodule BlockScoutWeb.Schemas.API.V2.SignedAuthorization do
  @moduledoc """
  This module defines the schema for the SignedAuthorization struct.
  """
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.General
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    type: :object,
    properties: %{
      address_hash: General.AddressHash,
      chain_id: %Schema{type: :integer, nullable: false},
      nonce: General.IntegerString,
      r: General.IntegerString,
      s: General.IntegerString,
      v: %Schema{type: :integer, nullable: false},
      authority: General.AddressHash,
      status: %Schema{
        type: :string,
        enum: ["ok", "invalid_chain_id", "invalid_signature", "invalid_nonce"],
        nullable: true
      }
    },
    required: [:address_hash, :chain_id, :nonce, :r, :s, :v, :authority, :status],
    additionalProperties: false
  })
end
