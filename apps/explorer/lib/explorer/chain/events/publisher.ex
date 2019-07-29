defmodule Explorer.Chain.Events.Publisher do
  @moduledoc """
  Publishes events related to the Chain context.
  """
  alias Ecto.Adapters.SQL.Sandbox
  alias Explorer.Repo

  @allowed_events ~w(addresses address_coin_balances blocks block_rewards internal_transactions token_transfers transactions contract_verification_result)a

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
    payload = encode_payload({:chain_event, event_type})
    send_notify(payload)
  end

  # The :catchup type of event is not being consumed right now.
  # To avoid a large number of unread messages in the `mailbox` the dispatch of
  # these type of events is disabled for now.
  defp send_data(_event_type, :catchup, _event_data), do: :ok

  defp send_data(event_type, broadcast_type, event_data) do
    payload = encode_payload({:chain_event, event_type, broadcast_type, event_data})
    send_notify(payload)
  end

  defp encode_payload(payload) do
    payload
    |> :erlang.term_to_binary([:compressed])
    |> Base.encode64()
  end

  defp send_notify(payload) do
    fun = fn ->
      Repo.query("select pg_notify('chain_event', $1::text);", [payload])
    end

    if Mix.env() == :test do
      Sandbox.unboxed_run(Repo, fun)
    else
      fun.()
    end
  end
end
