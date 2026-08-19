# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule BlockScoutWeb.RealtimeEventHandlers.Main do
  @moduledoc """
  Subscribing process for broadcast events from realtime.
  """
  use BlockScoutWeb.RealtimeEventHandler
  use Utils.CompileTimeEnvHelper, chain_type: [:explorer, :chain_type]

  alias Explorer.Chain.Events.Subscriber

  case @chain_type do
    :arbitrum ->
      defp chain_type_specific_subscriptions do
        Subscriber.to(:new_arbitrum_batches, :realtime)
        Subscriber.to(:new_messages_to_arbitrum_amount, :realtime)
      end

    :optimism ->
      defp chain_type_specific_subscriptions do
        Subscriber.to(:new_optimism_batches, :realtime)
        Subscriber.to(:new_optimism_deposits, :realtime)
      end

    _ ->
      defp chain_type_specific_subscriptions do
        nil
      end
  end

  @impl BlockScoutWeb.RealtimeEventHandler
  def subscribe do
    Subscriber.to(:address_coin_balances, :realtime)
    Subscriber.to(:addresses, :realtime)
    Subscriber.to(:block_rewards, :realtime)
    Subscriber.to(:internal_transactions, :realtime)
    Subscriber.to(:internal_transactions, :on_demand)
    Subscriber.to(:addresses, :on_demand)
    Subscriber.to(:address_coin_balances, :on_demand)
    Subscriber.to(:address_current_token_balances, :on_demand)
    Subscriber.to(:address_current_token_balances, :realtime)
    Subscriber.to(:address_token_balances, :on_demand)
    Subscriber.to(:token_total_supply, :on_demand)
    Subscriber.to(:changed_bytecode, :on_demand)
    Subscriber.to(:fetched_bytecode, :on_demand)
    Subscriber.to(:fetched_token_instance_metadata, :on_demand)
    Subscriber.to(:not_fetched_token_instance_metadata, :on_demand)
    Subscriber.to(:zkevm_confirmed_batches, :realtime)
    # Does not come from the indexer
    Subscriber.to(:exchange_rate)
    Subscriber.to(:transaction_stats)

    chain_type_specific_subscriptions()
  end
end
