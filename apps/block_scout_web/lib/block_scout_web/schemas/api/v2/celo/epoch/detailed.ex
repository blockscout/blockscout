# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule BlockScoutWeb.Schemas.API.V2.Celo.Epoch.Detailed do
  @moduledoc """
  This module defines the schema for detailed Celo epoch response.
  """
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.{Celo.Epoch, General}
  alias BlockScoutWeb.Schemas.API.V2.Celo.Epoch.{AggregatedElectionRewards, DetailedDistribution}
  alias BlockScoutWeb.Schemas.Helper
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(
    Epoch.schema()
    |> Helper.extend_schema(
      title: "CeloEpochDetailed",
      nullable: false,
      properties: %{
        start_processing_block_hash: General.FullHashNullable,
        start_processing_block_number: %Schema{type: :integer, nullable: true, minimum: 0},
        end_processing_block_hash: General.FullHashNullable,
        end_processing_block_number: %Schema{type: :integer, nullable: true, minimum: 0},
        aggregated_election_rewards: %Schema{allOf: [AggregatedElectionRewards], nullable: true},
        distribution: %Schema{allOf: [DetailedDistribution], nullable: true}
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
