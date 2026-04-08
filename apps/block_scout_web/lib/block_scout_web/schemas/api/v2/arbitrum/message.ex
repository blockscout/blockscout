defmodule BlockScoutWeb.Schemas.API.V2.Arbitrum.Message do
  @moduledoc """
  Full Arbitrum cross-chain message schema.

  Extends `MinimalMessage` with: `id`, `origination_address_hash`, `status`.
  """

  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.Arbitrum.MinimalMessage
  alias BlockScoutWeb.Schemas.API.V2.General
  alias BlockScoutWeb.Schemas.Helper
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(
    MinimalMessage.schema()
    |> Helper.extend_schema(
      title: "Arbitrum.Message",
      description: "Full Arbitrum cross-chain message.",
      properties: %{
        id: %Schema{type: :integer, minimum: 0, description: "Message ID."},
        origination_address_hash: General.AddressHashNullable,
        # Enum values must be kept in sync with Explorer.Chain.Arbitrum.Message :status field.
        status: %Schema{type: :string, enum: ["initiated", "sent", "confirmed", "relayed"]}
      },
      required: [:id, :origination_address_hash, :status]
    )
  )
end
