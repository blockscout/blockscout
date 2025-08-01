defmodule BlockScoutWeb.RealtimeEventHandler do
  @moduledoc """
  Subscribing process for broadcast events from realtime.
  """
  use GenServer
  use Utils.CompileTimeEnvHelper, chain_type: [:explorer, :chain_type]

  alias BlockScoutWeb.Notifier
  alias Explorer.Chain.Events.Subscriber

  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  case @chain_type do
    :arbitrum ->
      def chain_type_specific_subscriptions do
        Subscriber.to(:new_arbitrum_batches, :realtime)
        Subscriber.to(:new_messages_to_arbitrum_amount, :realtime)
      end

    :optimism ->
      def chain_type_specific_subscriptions do
        Subscriber.to(:new_optimism_batches, :realtime)
        Subscriber.to(:new_optimism_deposits, :realtime)
      end

    _ ->
      def chain_type_specific_subscriptions do
        nil
      end
  end

  @impl true
  def init([]) do
    Subscriber.to(:address_coin_balances, :realtime)
    Subscriber.to(:addresses, :realtime)
    Subscriber.to(:block_rewards, :realtime)
    Subscriber.to(:internal_transactions, :realtime)
    Subscriber.to(:internal_transactions, :on_demand)
    Subscriber.to(:token_transfers, :realtime)
    Subscriber.to(:addresses, :on_demand)
    Subscriber.to(:address_coin_balances, :on_demand)
    Subscriber.to(:address_current_token_balances, :on_demand)
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

    {:ok, []}
  end

  @impl true
  def handle_info(event, state) do
    Notifier.handle_event(event)
    {:noreply, state}
  end
end
