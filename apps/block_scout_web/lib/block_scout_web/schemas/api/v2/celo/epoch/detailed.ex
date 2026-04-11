defmodule BlockScoutWeb.Schemas.API.V2.Celo.Epoch.Detailed do
  @moduledoc """
  This module defines the schema for detailed Celo epoch response.
  """
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.{Celo.Epoch, General}
  alias BlockScoutWeb.Schemas.Helper
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(
    Epoch.schema()
    |> Helper.extend_schema(
      nullable: false,
      properties: %{
        start_processing_block_hash: General.FullHashNullable,
        start_processing_block_number: %Schema{type: :integer, nullable: true, minimum: 0},
        end_processing_block_hash: General.FullHashNullable,
        end_processing_block_number: %Schema{type: :integer, nullable: true, minimum: 0},
        aggregated_election_rewards: %Schema{
          type: :object,
          nullable: true,
          additionalProperties: %Schema{
            anyOf: [
              %Schema{
                type: :object,
                properties: %{
                  total: General.IntegerString,
                  count: %Schema{type: :integer, nullable: false, minimum: 0},
                  token: %Schema{type: :object, nullable: true, additionalProperties: true}
                },
                required: [:total, :count, :token],
                additionalProperties: false
              },
              %Schema{type: :null}
            ]
          }
        },
        distribution: %Schema{type: :object, nullable: true, additionalProperties: true}
      },
      required: [
        :start_processing_block_hash,
        :start_processing_block_number,
        :end_processing_block_hash,
        :end_processing_block_number,
        :aggregated_election_rewards
      ]
    )
  )
end
