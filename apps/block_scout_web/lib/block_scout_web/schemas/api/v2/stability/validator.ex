# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule BlockScoutWeb.Schemas.API.V2.Stability.Validator do
  @moduledoc """
  This module defines the schema for the Stability Validator struct.
  """
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.Address
  alias Ecto.Enum, as: EctoEnum
  alias Explorer.Chain.Stability.Validator, as: ValidatorStability
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "StabilityValidator",
    description:
      "Validator on the Stability chain. Stability validators are the addresses authorized to produce blocks; each entry tracks the validator's operational state and the number of blocks it has produced so far.",
    type: :object,
    properties: %{
      address: Address,
      state: %Schema{
        type: :string,
        # Keep in sync with `state` field of `Explorer.Chain.Stability.Validator`.
        enum: EctoEnum.values(ValidatorStability, :state) |> Enum.map(&to_string/1),
        nullable: true,
        description:
          "Operational state of the validator (`active` — producing blocks, `probation` — missed blocks but still in the active set, `inactive` — removed from the active set)."
      },
      blocks_validated_count: %Schema{
        type: :integer,
        minimum: 0,
        nullable: false,
        description: "Total number of blocks produced by this validator."
      }
    },
    required: [
      :address,
      :state,
      :blocks_validated_count
    ],
    additionalProperties: false
  })
end
