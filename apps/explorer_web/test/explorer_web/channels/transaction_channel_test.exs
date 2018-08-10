defmodule ExplorerWeb.TransactionChannelTest do
  use ExplorerWeb.ChannelCase

  alias ExplorerWeb.Notifier

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
end
