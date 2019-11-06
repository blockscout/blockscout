defmodule Explorer.Chain.Events.SubscriberTest do
  use ExUnit.Case, async: true

  doctest Explorer.Chain.Events.Subscriber

  alias Explorer.Chain.Events.{Publisher, Subscriber}

  describe "to/2" do
    test "receives event when there is a type of broadcast" do
      event_type = :blocks
      broadcast_type = :realtime
      event_data = []

      Subscriber.to(event_type, broadcast_type)

      Publisher.broadcast([{event_type, event_data}], broadcast_type)

      assert_receive {:chain_event, :blocks, :realtime, []}
    end
  end

  describe "to/1" do
    test "receives event when there is not a type of broadcast" do
      event_type = :exchange_rate

      Subscriber.to(event_type)

      Publisher.broadcast(event_type)

      assert_receive {:chain_event, :exchange_rate}
    end
  end
end
