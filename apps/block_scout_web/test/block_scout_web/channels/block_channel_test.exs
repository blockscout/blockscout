defmodule BlockScoutWeb.BlockChannelTest do
  use BlockScoutWeb.ChannelCase

  alias BlockScoutWeb.Notifier
  alias Explorer.Chain.Cache.Counters.AverageBlockTime

  test "subscribed user is notified of new_block event" do
    topic = "blocks_old:new_block"
    @endpoint.subscribe(topic)

    block = insert(:block, number: 1)

    start_supervised!(AverageBlockTime)
    Application.put_env(:explorer, AverageBlockTime, enabled: true, cache_period: 1_800_000)

    on_exit(fn ->
      Application.put_env(:explorer, AverageBlockTime, enabled: false, cache_period: 1_800_000)
    end)

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
