defmodule BlockScoutWeb.BlockViewTest do
  use BlockScoutWeb.ConnCase, async: true

  alias BlockScoutWeb.BlockView
  alias Explorer.Repo

  describe "average_gas_price/1" do
    test "returns an average of the gas prices for a block's transactions with the unit value" do
      block = insert(:block)

      Enum.each(1..10, fn index ->
        :transaction
        |> insert(gas_price: 10_000_000_000 * index)
        |> with_block(block)
      end)

      assert "55 Gwei" == BlockView.average_gas_price(Repo.preload(block, [:transactions]))
    end
  end

  describe "block_type/1" do
    test "returns Block" do
      block = insert(:block, nephews: [])

      assert BlockView.block_type(block) == "Block"
    end

    test "returns Reorg" do
      reorg = insert(:block, consensus: false, nephews: [])

      assert BlockView.block_type(reorg) == "Reorg"
    end

    test "returns Uncle" do
      uncle = insert(:block, consensus: false)
      insert(:block_second_degree_relation, uncle_hash: uncle.hash)

      assert BlockView.block_type(uncle) == "Uncle"
    end
  end

  describe "formatted_timestamp/1" do
    test "returns a formatted timestamp string for a block" do
      block = insert(:block)

      assert Timex.format!(block.timestamp, "%b-%d-%Y %H:%M:%S %p %Z", :strftime) ==
               BlockView.formatted_timestamp(block)
    end
  end

  describe "show_reward?/1" do
    test "returns false when list of rewards is empty" do
      assert BlockView.show_reward?([]) == false
    end

    test "returns true when list of rewards is not empty" do
      block = insert(:block)
      validator = insert(:reward, address_hash: block.miner_hash, block_hash: block.hash, address_type: :validator)

      assert BlockView.show_reward?([validator]) == true
    end
  end

  describe "combined_rewards_value/1" do
    test "returns all the reward values summed up and formatted into a String" do
      block = insert(:block)

      insert(
        :reward,
        address_hash: block.miner_hash,
        block_hash: block.hash,
        address_type: :validator,
        reward: Decimal.new(1_000_000_000_000_000_000)
      )

      insert(
        :reward,
        address_hash: block.miner_hash,
        block_hash: block.hash,
        address_type: :emission_funds,
        reward: Decimal.new(1_000_000_000_000_000_000)
      )

      insert(
        :reward,
        address_hash: block.miner_hash,
        block_hash: block.hash,
        address_type: :uncle,
        reward: Decimal.new(1_000_042_000_000_000_000)
      )

      block = Repo.preload(block, :rewards)

      assert BlockView.combined_rewards_value(block) == "3.000042 Ether"
    end
  end
end
