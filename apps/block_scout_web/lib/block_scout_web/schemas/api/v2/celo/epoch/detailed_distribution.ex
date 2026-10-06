# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule BlockScoutWeb.Schemas.API.V2.Celo.Epoch.DetailedDistributionTotal do
  @moduledoc """
  Aggregated total of all epoch reward transfers (with their common token), as
  produced by `CeloView.calculate_total_epoch_rewards/1`.
  """
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.{Token, TokenTransfer}

  OpenApiSpex.schema(%{
    title: "CeloEpochDetailedDistributionTotal",
    type: :object,
    properties: %{
      token: Token,
      total: TokenTransfer.Total
    },
    required: [:token, :total],
    additionalProperties: false
  })
end

defmodule BlockScoutWeb.Schemas.API.V2.Celo.Epoch.DetailedDistribution do
  @moduledoc """
  Epoch reward distribution as rendered for the detailed Celo epoch response
  (`CeloView.prepare_distribution/1`). Each transfer is the full token transfer,
  and `transfers_total` is the aggregated sum across them.
  """
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.Celo.Epoch.DetailedDistributionTotal
  alias BlockScoutWeb.Schemas.API.V2.TokenTransfer
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "CeloEpochDetailedDistribution",
    description: "Epoch reward token transfers and their aggregated total.",
    type: :object,
    properties: %{
      reserve_bolster_transfer: %Schema{allOf: [TokenTransfer], nullable: true},
      community_transfer: %Schema{allOf: [TokenTransfer], nullable: true},
      carbon_offsetting_transfer: %Schema{allOf: [TokenTransfer], nullable: true},
      transfers_total: %Schema{allOf: [DetailedDistributionTotal], nullable: true}
    },
    required: [
      :reserve_bolster_transfer,
      :community_transfer,
      :carbon_offsetting_transfer,
      :transfers_total
    ],
    additionalProperties: false
  })
end
