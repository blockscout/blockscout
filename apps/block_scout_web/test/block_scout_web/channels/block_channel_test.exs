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
      5_000 ->
        assert false, "Expected message received nothing."
    end
  end

  test "miner address is notified of new_block they validated" do
    miner = insert(:address)
    topic = "blocks:#{to_string(miner.hash)}"
    @endpoint.subscribe(topic)

    block = insert(:block, number: 1, miner: miner)

    Notifier.handle_event({:chain_event, :blocks, :realtime, [block]})

    receive do
      %Phoenix.Socket.Broadcast{topic: ^topic, event: "new_block", payload: %{block: _}} ->
        assert true
    after
      5_000 ->
        assert false, "Expected message received nothing."
    end
  end

  test "subscribed user is notified of indexing status" do
    topic = "blocks:indexing"
    @endpoint.subscribe(topic)

    Notifier.handle_event({:chain_event, :blocks, :catchup, []})

    receive do
      %Phoenix.Socket.Broadcast{topic: ^topic, event: "index_status", payload: payload} ->
        assert payload.ratio == 0
        refute payload.finished
    after
      5_000 ->
        assert false, "Expected message received nothing."
    end
  end

  test "subscribed user is notified of new_block event for catchup" do
    topic = "blocks:new_block"
    @endpoint.subscribe(topic)

    block = insert(:block, number: 1)

    Notifier.handle_event({:chain_event, :blocks, :catchup, [block]})

    receive do
      %Phoenix.Socket.Broadcast{topic: ^topic, event: "new_block", payload: %{block: _}} ->
        assert true
    after
      5_000 ->
        assert false, "Expected message received nothing."
    end
  end
end
