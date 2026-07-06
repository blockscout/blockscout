# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule BlockScoutWeb.Schemas.API.V2.Celo.Epoch.AggregatedElectionReward do
  @moduledoc """
  Aggregated election reward of a single type within a Celo epoch.
  """
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.{General, Token}
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "CeloEpochAggregatedElectionReward",
    type: :object,
    properties: %{
      total: General.IntegerString,
      count: %Schema{type: :integer, nullable: false, minimum: 0},
      token: Token
    },
    required: [:total, :count, :token],
    additionalProperties: false
  })
end

defmodule BlockScoutWeb.Schemas.API.V2.Celo.Epoch.AggregatedElectionRewards do
  @moduledoc """
  Election rewards of a Celo epoch aggregated by reward type. Keys correspond to
  `Explorer.Chain.Celo.ElectionReward` types; `delegated_payment` is `null` for
  post-migration (L2) epochs.
  """
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.Celo.Epoch.AggregatedElectionReward
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "CeloEpochAggregatedElectionRewards",
    type: :object,
    properties: %{
      voter: %Schema{allOf: [AggregatedElectionReward], nullable: true},
      validator: %Schema{allOf: [AggregatedElectionReward], nullable: true},
      group: %Schema{allOf: [AggregatedElectionReward], nullable: true},
      delegated_payment: %Schema{allOf: [AggregatedElectionReward], nullable: true}
    },
    required: [:voter, :validator, :group, :delegated_payment],
    additionalProperties: false
  })
end
