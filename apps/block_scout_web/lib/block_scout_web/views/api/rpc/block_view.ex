defmodule BlockScoutWeb.API.RPC.BlockView do
  use BlockScoutWeb, :view

  alias BlockScoutWeb.API.RPC.{EthRPCView, RPCView}
  alias Explorer.Chain.{Hash, Wei}

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

  def render("eth_block_number.json", %{number: number, id: id}) do
    result = encode_quantity(number)

    EthRPCView.render("show.json", %{result: result, id: id})
  end

  def render("error.json", %{error: error}) do
    RPCView.render("error.json", error: error)
  end

  defp encode_quantity(binary) when is_binary(binary) do
    hex_binary = Base.encode16(binary, case: :lower)

    result = String.replace_leading(hex_binary, "0", "")

    final_result = if result == "", do: "0", else: result

    "0x#{final_result}"
  end

  defp encode_quantity(value) when is_integer(value) do
    value
    |> :binary.encode_unsigned()
    |> encode_quantity()
  end

  defp encode_quantity(value) when is_nil(value) do
    nil
  end
end
