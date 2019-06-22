defmodule BlockScoutWeb.StakingEpochChannelTest do
  use BlockScoutWeb.ChannelCase

  alias BlockScoutWeb.Notifier

  test "subscribed user is notified of new_epoch event" do
    topic = "staking_epoch:new_epoch"
    @endpoint.subscribe(topic)

    Notifier.handle_event({:chain_event, :staking_epoch})

    receive do
      %Phoenix.Socket.Broadcast{topic: ^topic, event: "new_epoch", payload: %{epoch_number: _}} ->
        assert true
    after
      :timer.seconds(5) ->
        assert false, "Expected message received nothing."
    end
  end
end
