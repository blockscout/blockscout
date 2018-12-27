defmodule BlockScoutWeb.BlockChannelTest do
  use BlockScoutWeb.ChannelCase

  alias BlockScoutWeb.Notifier

  test "subscribed user is notified of new_block event" do
    topic = "blocks:new_block"
    @endpoint.subscribe(topic)

    block = insert(:block, number: 1)

    Notifier.handle_event({:chain_event, :blocks, :realtime, [block]})

    receive do
      %Phoenix.Socket.Broadcast{topic: ^topic, event: "new_block", payload: %{block: _}} ->
        assert true
    after
      :timer.seconds(5) ->
        assert false, "Expected message received nothing."
    end
  end
end
