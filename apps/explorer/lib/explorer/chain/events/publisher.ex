defmodule Explorer.Chain.Events.Publisher do
  @moduledoc """
  Publishes events related to the Chain context.
  """
  use Utils.CompileTimeEnvHelper, chain_type: [:explorer, :chain_type]

  @common_allowed_events ~w(addresses address_coin_balances address_token_balances
    address_current_token_balances blocks block_rewards internal_transactions
    last_block_number token_transfers transactions contract_verification_result
    token_total_supply changed_bytecode fetched_bytecode fetched_token_instance_metadata not_fetched_token_instance_metadata
    smart_contract_was_verified zkevm_confirmed_batches eth_bytecode_db_lookup_started
    smart_contract_was_not_verified)a

  case @chain_type do
    :arbitrum ->
      @chain_type_specific_allowed_events ~w(new_arbitrum_batches new_messages_to_arbitrum_amount)a

    :optimism ->
      @chain_type_specific_allowed_events ~w(new_optimism_batches new_optimism_deposits)a

    _ ->
      @chain_type_specific_allowed_events ~w()a
  end

  @allowed_events @common_allowed_events ++ @chain_type_specific_allowed_events

  def broadcast(_data, false), do: :ok

  def broadcast(data, broadcast_type) do
    for {event_type, event_data} <- data, event_type in @allowed_events do
      send_data(event_type, broadcast_type, event_data)
    end
  end

  @spec broadcast(atom()) :: :ok
  def broadcast(event_type) do
    send_data(event_type)
    :ok
  end

  defp send_data(event_type) do
    sender().send_data(event_type)
  end

  defp sender do
    Application.get_env(:explorer, :realtime_events_sender)
  end

  # The :catchup type of event is not being consumed right now.
  # To avoid a large number of unread messages in the `mailbox` the dispatch of
  # these type of events is disabled for now.
  defp send_data(_event_type, :catchup, _event_data), do: :ok

  defp send_data(event_type, broadcast_type, event_data) do
    sender().send_data(event_type, broadcast_type, event_data)
  end
end
