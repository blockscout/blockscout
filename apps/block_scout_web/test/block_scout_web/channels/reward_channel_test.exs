defmodule BlockScoutWeb.RewardChannelTest do
  use BlockScoutWeb.ChannelCase, async: false

  alias BlockScoutWeb.Notifier

  describe "user subscribed to rewards" do
    test "does nothing if the configuration is turned off" do
      Application.put_env(:block_scout_web, BlockScoutWeb.Chain, has_emission_funds: false)

      address = insert(:address)
      block = insert(:block)
      reward = insert(:reward, address_hash: address.hash, block_hash: block.hash)

      topic = "rewards:#{address.hash}"
      @endpoint.subscribe(topic)

      Notifier.handle_event({:chain_event, :block_rewards, :realtime, [reward]})

      refute_receive _, :timer.seconds(2)

      Application.put_env(:block_scout_web, BlockScoutWeb.Chain, has_emission_funds: false)
    end

    test "notified of new reward for matching address" do
      Application.put_env(:block_scout_web, BlockScoutWeb.Chain, has_emission_funds: true)
      address = insert(:address)
      block = insert(:block)
      reward = insert(:reward, address_hash: address.hash, block_hash: block.hash)

      topic = "rewards:#{address.hash}"
      @endpoint.subscribe(topic)

      Notifier.handle_event({:chain_event, :block_rewards, :realtime, [reward]})

      assert_receive %Phoenix.Socket.Broadcast{topic: ^topic, event: "new_reward", payload: _}, :timer.seconds(5)

      Application.put_env(:block_scout_web, BlockScoutWeb.Chain, has_emission_funds: false)
    end

    test "not notified of new reward for other address" do
      Application.put_env(:block_scout_web, BlockScoutWeb.Chain, has_emission_funds: true)

      address = insert(:address)
      block = insert(:block)
      reward = insert(:reward, address_hash: address.hash, block_hash: block.hash)

      topic = "rewards:0x0"
      @endpoint.subscribe(topic)

      Notifier.handle_event({:chain_event, :block_rewards, :realtime, [reward]})

      refute_receive _, :timer.seconds(2)

      Application.put_env(:block_scout_web, BlockScoutWeb.Chain, has_emission_funds: false)
    end
  end
end
