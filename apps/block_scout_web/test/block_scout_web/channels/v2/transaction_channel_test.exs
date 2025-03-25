defmodule BlockScoutWeb.V2.TransactionChannelTest do
  use BlockScoutWeb.ChannelCase

  alias BlockScoutWeb.Notifier

  test "subscribed user is notified of new_transaction topic" do
    topic = "transactions:new_transaction"
    @endpoint.subscribe(topic)

    transaction =
      :transaction
      |> insert()
      |> with_block()

    Notifier.handle_event({:chain_event, :transactions, :realtime, [transaction]})

    receive do
      %Phoenix.Socket.Broadcast{topic: ^topic, event: "transaction", payload: %{transaction: _transaction} = payload} ->
        assert payload.transaction == 1
    after
      :timer.seconds(5) ->
        assert false, "Expected message received nothing."
    end
  end

  test "subscribed user is notified of new_pending_transaction topic" do
    topic = "transactions:new_pending_transaction"
    @endpoint.subscribe(topic)

    pending = insert(:transaction)

    Notifier.handle_event({:chain_event, :transactions, :realtime, [pending]})

    receive do
      %Phoenix.Socket.Broadcast{
        topic: ^topic,
        event: "pending_transaction",
        payload: %{pending_transaction: _transaction} = payload
      } ->
        assert payload.pending_transaction == 1
    after
      :timer.seconds(5) ->
        assert false, "Expected message received nothing."
    end
  end
end
