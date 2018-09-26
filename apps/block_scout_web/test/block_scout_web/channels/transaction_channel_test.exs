defmodule BlockScoutWeb.TransactionChannelTest do
  use BlockScoutWeb.ChannelCase

  alias BlockScoutWeb.Notifier

  test "subscribed user is notified of new_transaction event" do
    topic = "transactions:new_transaction"
    @endpoint.subscribe(topic)

    transaction =
      :transaction
      |> insert()
      |> with_block()

    Notifier.handle_event({:chain_event, :transactions, [transaction.hash]})

    receive do
      %Phoenix.Socket.Broadcast{topic: ^topic, event: "new_transaction", payload: payload} ->
        assert payload.transaction.hash == transaction.hash
    after
      5_000 ->
        assert false, "Expected message received nothing."
    end
  end

  test "subscribed user is notified of new_pending_transaction event" do
    topic = "transactions:new_pending_transaction"
    @endpoint.subscribe(topic)

    pending = insert(:transaction)

    Notifier.handle_event({:chain_event, :transactions, [pending.hash]})

    receive do
      %Phoenix.Socket.Broadcast{topic: ^topic, event: "new_pending_transaction", payload: payload} ->
        assert payload.transaction.hash == pending.hash
    after
      5_000 ->
        assert false, "Expected message received nothing."
    end
  end
end
