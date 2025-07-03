defmodule BlockScoutWeb.API.RPC.BlockView do
  use BlockScoutWeb, :view

  alias BlockScoutWeb.API.EthRPC.View, as: EthRPCView
  alias BlockScoutWeb.API.RPC.RPCView
  alias Explorer.Chain.{Block, Hash, Wei}
  alias Explorer.EthRPC, as: EthRPC

  def render("block_reward.json", %{block: %Block{rewards: [_ | _]} = block}) do
    reward_as_string =
      block.rewards
      |> Enum.find(%{reward: %Wei{value: Decimal.new(0)}}, &(&1.address_type == :validator))
      |> Map.get(:reward)
      |> Wei.to(:wei)
      |> Decimal.to_string(:normal)

    static_reward =
      block.rewards
      |> Enum.find(%{reward: %Wei{value: Decimal.new(0)}}, &(&1.address_type == :emission_funds))
      |> Map.get(:reward)
      |> Wei.to(:wei)

    uncles =
      block.rewards
      |> Stream.filter(&(&1.address_type == :uncle))
      |> Stream.with_index()
      |> Enum.map(fn {reward, index} ->
        %{
          "unclePosition" => to_string(index),
          "miner" => Hash.to_string(reward.address_hash),
          "blockreward" => reward.reward |> Wei.to(:wei) |> Decimal.to_string(:normal)
        }
      end)

    data = %{
      "blockNumber" => to_string(block.number),
      "timeStamp" => DateTime.to_unix(block.timestamp),
      "blockMiner" => Hash.to_string(block.miner_hash),
      "blockReward" => reward_as_string,
      "uncles" => uncles,
      "uncleInclusionReward" =>
        static_reward
        |> Decimal.mult(Enum.count(uncles))
        |> Decimal.div(Block.uncle_reward_coef())
        |> Decimal.to_string(:normal)
    }

    RPCView.render("show.json", data: data)
  end

  def render("block_reward.json", %{block: block}) do
    data = %{
      "blockNumber" => to_string(block.number),
      "timeStamp" => DateTime.to_unix(block.timestamp),
      "blockMiner" => Hash.to_string(block.miner_hash),
      "blockReward" => "0",
      "uncles" => [],
      "uncleInclusionReward" => "0"
    }

    RPCView.render("show.json", data: data)
  end

  def render("block_countdown.json", %{
        current_block: current_block,
        countdown_block: countdown_block,
        remaining_blocks: remaining_blocks,
        estimated_time_in_sec: estimated_time_in_sec
      }) do
    data = %{
      "CurrentBlock" => to_string(current_block),
      "CountdownBlock" => to_string(countdown_block),
      "RemainingBlock" => to_string(remaining_blocks),
      "EstimateTimeInSec" => to_string(estimated_time_in_sec)
    }

    RPCView.render("show.json", data: data)
  end

  def render("getblocknobytime.json", %{block_number: block_number}) do
    RPCView.render("show.json", data: to_string(block_number))
  end

  def render("eth_block_number.json", %{number: number, id: id}) do
    result = EthRPC.encode_quantity(number)

    EthRPCView.render("show.json", %{result: result, id: id})
  end

  def render("error.json", %{error: error}) do
    RPCView.render("error.json", error: error)
  end
end
