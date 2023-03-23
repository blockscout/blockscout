defmodule Explorer.Chain.Events.Subscriber do
  @moduledoc """
  Subscribes to events related to the Chain context.
  """

  @allowed_broadcast_events ~w(addresses address_coin_balances address_token_balances blocks block_rewards internal_transactions last_block_number optimism_reorg_block token_transfers transactions contract_verification_result token_total_supply changed_bytecode)a

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
