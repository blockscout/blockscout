defmodule BlockScoutWeb.API.RPC.BlockView do
  use BlockScoutWeb, :view

  alias Explorer.Chain.{Hash, Wei}
  alias BlockScoutWeb.API.RPC.RPCView

  def render("block_reward.json", %{block: block, reward: reward}) do
    reward_as_string =
      reward
      |> Wei.to(:wei)
      |> Decimal.to_string(:normal)

    data = %{
      "blockNumber" => to_string(block.number),
      "timeStamp" => DateTime.to_unix(block.timestamp),
      "blockMiner" => Hash.to_string(block.miner_hash),
      "blockReward" => reward_as_string,
      "uncles" => nil,
      "uncleInclusionReward" => nil
    }

    RPCView.render("show.json", data: data)
  end

  def render("error.json", %{error: error}) do
    RPCView.render("error.json", error: error)
  end
end
