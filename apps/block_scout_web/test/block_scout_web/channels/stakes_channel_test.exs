defmodule BlockScoutWeb.StakesChannelTest do
  use BlockScoutWeb.ChannelCase

  alias BlockScoutWeb.StakingEventHandler

  test "subscribed user is notified of staking_update event" do
    topic = "stakes:staking_update"
    @endpoint.subscribe(topic)

    data = %{
      block_number: 76,
      epoch_number: 0,
      staking_allowed: false,
      staking_token_defined: false,
      validator_set_apply_block: 0
    }

    StakingEventHandler.handle_info({:chain_event, :staking_update, :realtime, data}, nil)

    receive do
      %Phoenix.Socket.Broadcast{topic: ^topic, event: "staking_update", payload: %{epoch_number: _}} ->
        assert true
    after
      :timer.seconds(5) ->
        assert false, "Expected message received nothing."
    end
  end
end
