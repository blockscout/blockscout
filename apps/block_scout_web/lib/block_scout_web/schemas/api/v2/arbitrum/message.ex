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
        id: %Schema{
          type: :integer,
          minimum: 0,
          description: "Unique cross-chain message identifier assigned by the protocol."
        },
        origination_address_hash: %Schema{
          allOf: [General.AddressHashNullable],
          description: "Address that initiated the message on the originating chain."
        },
        # Enum values must be kept in sync with Explorer.Chain.Arbitrum.Message :status field.
        status: %Schema{
          type: :string,
          enum: ["initiated", "sent", "confirmed", "relayed"],
          description:
            "Cross-chain message lifecycle. For Rollup→Parent messages: " <>
              "`initiated` (L2ToL1Tx event emitted on Rollup) → " <>
              "`sent` (included in a batch committed to Parent chain) → " <>
              "`confirmed` (batch state root posted to the Outbox contract) → " <>
              "`relayed` (executed on Parent chain). " <>
              "For Parent→Rollup messages only `initiated` and `relayed` apply."
        }
      },
      required: [:id, :origination_address_hash, :status]
    )
  )
end
