defmodule BlockScoutWeb.StakesChannelTest do
  use BlockScoutWeb.ChannelCase

  alias BlockScoutWeb.Notifier

  test "subscribed user is notified of staking_update event" do
    topic = "stakes:staking_update"
    @endpoint.subscribe(topic)

    Notifier.handle_event({:chain_event, :staking_update})

    receive do
      %Phoenix.Socket.Broadcast{topic: ^topic, event: "staking_update", payload: %{epoch_number: _}} ->
        assert true
    after
      :timer.seconds(5) ->
        assert false, "Expected message received nothing."
    end
  end
end
