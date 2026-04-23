defmodule BlockScoutWeb.Schemas.API.V2.Address.TabsCounters do
  @moduledoc """
  This module defines the schema for the Address.TabsCounters struct.
  """
  require OpenApiSpex

  use Utils.CompileTimeEnvHelper,
    chain_type: [:explorer, :chain_type],
    chain_identity: [:explorer, :chain_identity]

  alias OpenApiSpex.Schema

  @base_properties %{
    transactions_count: %Schema{type: :integer, nullable: false},
    token_transfers_count: %Schema{type: :integer, nullable: false},
    token_balances_count: %Schema{type: :integer, nullable: false},
    logs_count: %Schema{type: :integer, nullable: false},
    withdrawals_count: %Schema{type: :integer, nullable: false},
    internal_transactions_count: %Schema{type: :integer, nullable: false},
    validations_count: %Schema{type: :integer, nullable: false}
  }

  case @chain_identity do
    {:optimism, :celo} ->
      @chain_identity_properties %{celo_election_rewards_count: %Schema{type: :integer, nullable: false}}

    _ ->
      @chain_identity_properties %{}
  end

  case @chain_type do
    :ethereum ->
      @chain_type_properties %{beacon_deposits_count: %Schema{type: :integer, nullable: false}}

    _ ->
      @chain_type_properties %{}
  end

  @properties @base_properties
              |> Map.merge(@chain_identity_properties)
              |> Map.merge(@chain_type_properties)

  OpenApiSpex.schema(%{
    title: "AddressTabsCounters",
    description: "Counters for address tabs",
    type: :object,
    properties: @properties,
    additionalProperties: false
  })
end
