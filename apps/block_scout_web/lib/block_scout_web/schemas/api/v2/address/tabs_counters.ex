defmodule BlockScoutWeb.Schemas.API.V2.Address.TabsCounters do
  @moduledoc """
  This module defines the schema for the Address.TabsCounters struct.
  """
  require OpenApiSpex

  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "AddressTabsCounters",
    description: "Counters for address tabs",
    type: :object,
    properties: %{
      transactions_count: %Schema{type: :integer, nullable: false},
      token_transfers_count: %Schema{type: :integer, nullable: false},
      token_balances_count: %Schema{type: :integer, nullable: false},
      logs_count: %Schema{type: :integer, nullable: false},
      withdrawals_count: %Schema{type: :integer, nullable: false},
      internal_transactions_count: %Schema{type: :integer, nullable: false},
      validations_count: %Schema{type: :integer, nullable: false},
      celo_election_rewards_count: %Schema{type: :integer, nullable: false}
    }
  })
end
