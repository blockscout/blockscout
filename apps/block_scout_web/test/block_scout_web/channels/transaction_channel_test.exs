defmodule BlockScoutWeb.TransactionChannelTest do
  use BlockScoutWeb.ChannelCase

  alias Explorer.Chain.Hash
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
        assert payload.transaction.hash == transaction.hash
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
        payload: %{transaction: _transaction} = payload
      } ->
        assert payload.transaction.hash == pending.hash
    after
      :timer.seconds(5) ->
        assert false, "Expected message received nothing."
    end
  end

  test "subscribed user is notified of transaction_hash collated event" do
    transaction =
      :transaction
      |> insert()
      |> with_block()

    topic = "transactions:#{Hash.to_string(transaction.hash)}"
    @endpoint.subscribe(topic)

    Notifier.handle_event({:chain_event, :transactions, :realtime, [transaction]})

    receive do
      %Phoenix.Socket.Broadcast{topic: ^topic, event: "collated", payload: %{}} ->
        assert true
    after
      :timer.seconds(5) ->
        assert false, "Expected message received nothing."
    end
  end
end
