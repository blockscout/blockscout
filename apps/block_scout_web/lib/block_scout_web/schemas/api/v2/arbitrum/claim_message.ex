defmodule BlockScoutWeb.Schemas.API.V2.Arbitrum.ClaimMessage do
  @moduledoc "Schema for Arbitrum claim message response."

  alias BlockScoutWeb.Schemas.API.V2.General
  alias OpenApiSpex.Schema

  require OpenApiSpex

  OpenApiSpex.schema(%{
    title: "Arbitrum.ClaimMessage",
    description: "Calldata and outbox contract address needed to execute a withdrawal on the Parent chain.",
    type: :object,
    required: [:calldata, :outbox_address_hash],
    properties: %{
      calldata: %Schema{type: :string, description: "ABI-encoded calldata for the executeTransaction call."},
      outbox_address_hash: %Schema{
        allOf: [General.AddressHash],
        description:
          "Address of the Arbitrum Outbox contract on the Parent chain through which the withdrawal is executed."
      }
    },
    additionalProperties: false
  })
end
