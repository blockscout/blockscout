defmodule Explorer.Chain.Events.PublisherTest do
  use ExUnit.Case, async: true

  doctest Explorer.Chain.Events.Publisher

  alias Explorer.Chain.Events.{Publisher, Subscriber}

  describe "broadcast/2" do
    test "sends chain_event of realtime type" do
      event_type = :blocks
      broadcast_type = :realtime
      event_data = []

      Subscriber.to(event_type, broadcast_type)

      Publisher.broadcast([{event_type, event_data}], broadcast_type)

      assert_receive {:chain_event, ^event_type, ^broadcast_type, []}
    end

    test "won't send chain_event of catchup type" do
      event_type = :blocks
      broadcast_type = :catchup
      event_data = []

      Subscriber.to(event_type, broadcast_type)

      Publisher.broadcast([{event_type, event_data}], broadcast_type)

      refute_received {:chain_event, ^event_type, ^broadcast_type, []}
    end

    test "won't send event that is not allowed" do
      event_type = :not_allowed
      broadcast_type = :catchup
      event_data = []

      Publisher.broadcast([{event_type, event_data}], broadcast_type)

      refute_received {:chain_event, ^event_type, ^broadcast_type, []}
    end

    test "won't send event of broadcast type not allowed" do
      event_type = :blocks
      broadcast_type = :something
      event_data = []

      Publisher.broadcast([{event_type, event_data}], broadcast_type)

      refute_received {:chain_event, ^event_type, ^broadcast_type, []}
    end
  end

  describe "broadcast/1" do
    test "sends event whithout type of broadcast" do
      event_type = :exchange_rate

      Subscriber.to(event_type)

      Publisher.broadcast(event_type)

      assert_receive {:chain_event, ^event_type}
    end
  end
end
