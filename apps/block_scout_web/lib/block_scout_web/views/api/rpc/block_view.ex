defmodule BlockScoutWeb.API.RPC.BlockView do
  use BlockScoutWeb, :view

  alias BlockScoutWeb.API.RPC.{EthRPCView, RPCView}
  alias Explorer.Chain.{Hash, Wei}
  alias Explorer.EthRPC, as: EthRPC

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

  def render("getblocknobytime.json", %{block_number: block_number}) do
    data = %{
      "blockNumber" => to_string(block_number)
    }

    RPCView.render("show.json", data: data)
  end

  def render("eth_block_number.json", %{number: number, id: id}) do
    result = EthRPC.encode_quantity(number)

    EthRPCView.render("show.json", %{result: result, id: id})
  end

  def render("error.json", %{error: error}) do
    RPCView.render("error.json", error: error)
  end
end
