defmodule Explorer.Chain.Events.Subscriber do
  @moduledoc """
  Subscribes to events related to the Chain context.
  """
  use Utils.CompileTimeEnvHelper, chain_type: [:explorer, :chain_type]

  @common_allowed_broadcast_events ~w(addresses address_coin_balances address_token_balances
    address_current_token_balances blocks block_rewards internal_transactions
    last_block_number token_transfers transactions contract_verification_result
    token_total_supply changed_bytecode fetched_bytecode fetched_token_instance_metadata not_fetched_token_instance_metadata
    smart_contract_was_verified zkevm_confirmed_batches eth_bytecode_db_lookup_started
    smart_contract_was_not_verified)a

  case @chain_type do
    :arbitrum ->
      @chain_type_specific_allowed_broadcast_events ~w(new_arbitrum_batches new_messages_to_arbitrum_amount)a

    :optimism ->
      @chain_type_specific_allowed_broadcast_events ~w(new_optimism_batches new_optimism_deposits)a

    _ ->
      @chain_type_specific_allowed_broadcast_events ~w()a
  end

  @allowed_broadcast_events @common_allowed_broadcast_events ++ @chain_type_specific_allowed_broadcast_events

  @allowed_broadcast_types ~w(catchup realtime on_demand contract_verification_result)a

  @allowed_events ~w(exchange_rate transaction_stats)a

  @type broadcast_type :: :realtime | :catchup | :on_demand

  @doc """
  Subscribes the caller process to a specified subset of chain-related events.

  ## Handling An Event

  A subscribed process should handle an event message. The message is in the
  format of a three-element tuple.

  * Element 0 - `:chain_event`
  * Element 1 - event subscribed to
  * Element 2 - event data in list form

  # A new block event in a GenServer
  def handle_info({:chain_event, :blocks, blocks}, state) do
  # Do something with the blocks
  end

  ## Example

  iex> Explorer.Chain.Events.Subscriber.to(:blocks, :realtime)
  :ok
  """
  @spec to(atom(), broadcast_type()) :: :ok
  def to(event_type, broadcast_type)
      when event_type in @allowed_broadcast_events and broadcast_type in @allowed_broadcast_types do
    Registry.register(Registry.ChainEvents, {event_type, broadcast_type}, [])
    :ok
  end

  @spec to(atom()) :: :ok
  def to(event_type) when event_type in @allowed_events do
    Registry.register(Registry.ChainEvents, event_type, [])
    :ok
  end
end
