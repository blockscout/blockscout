defmodule ExplorerWeb.BlockChannelTest do
  use ExplorerWeb.ChannelCase

  alias ExplorerWeb.Notifier

  test "subscribed user is notified of new_block event" do
    topic = "blocks:new_block"
    @endpoint.subscribe(topic)

    block = insert(:block, number: 1)

    Notifier.handle_event({:chain_event, :blocks, [block]})

    receive do
      %Phoenix.Socket.Broadcast{topic: ^topic, event: "new_block", payload: %{block: receive_block}} ->
        assert true
    after
      5_000 ->
        assert false, "Expected message received nothing."
    end
  end
end
