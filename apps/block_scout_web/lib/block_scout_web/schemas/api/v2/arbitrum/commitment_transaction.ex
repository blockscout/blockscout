defmodule BlockScoutWeb.Schemas.API.V2.Arbitrum.CommitmentTransaction do
  @moduledoc """
  Parent chain transaction that committed a batch.
  """
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.General
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    description: "Parent chain transaction that committed the batch.",
    type: :object,
    properties: %{
      hash: General.FullHashNullable,
      block_number: %Schema{type: :integer, minimum: 0, nullable: true},
      timestamp: General.TimestampNullable,
      status: %Schema{
        type: :string,
        nullable: true,
        description: "Finalization status of the Parent chain transaction."
      }
    },
    required: [:hash, :block_number, :timestamp, :status],
    additionalProperties: false
  })
end
