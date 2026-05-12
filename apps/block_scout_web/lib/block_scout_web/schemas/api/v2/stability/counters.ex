defmodule BlockScoutWeb.Schemas.API.V2.Stability.Counters do
  @moduledoc """
  This module defines the schema for the response from /api/v2/validators/stability/counters.
  """
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.General
  alias BlockScoutWeb.Schemas.Helper
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "StabilityValidatorsCounters",
    description: "Aggregate counters describing the Stability chain validator set.",
    type: :object,
    properties: %{
      validators_count:
        Helper.extend_schema(General.NonNegativeIntegerString.schema(),
          description: "Total number of validators known on the Stability chain across all operational states."
        ),
      new_validators_count_24h:
        Helper.extend_schema(General.NonNegativeIntegerString.schema(),
          description: "Number of validators that joined the set within the last 24 hours."
        ),
      active_validators_count:
        Helper.extend_schema(General.NonNegativeIntegerString.schema(),
          description: "Number of validators currently in the `active` operational state."
        ),
      active_validators_percentage: %Schema{
        type: :number,
        format: :float,
        minimum: 0,
        maximum: 100,
        nullable: true,
        description:
          "Share of `active` validators in the total set, expressed as a percentage and floored to two decimal places. `null` when there are no validators."
      }
    },
    required: [
      :validators_count,
      :new_validators_count_24h,
      :active_validators_count,
      :active_validators_percentage
    ],
    additionalProperties: false,
    example: %{
      validators_count: "9",
      new_validators_count_24h: "2",
      active_validators_count: "3",
      active_validators_percentage: 33.33
    }
  })
end
