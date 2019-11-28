defmodule BlockScoutWeb.API.RPC.BlockController do
  use BlockScoutWeb, :controller

  alias BlockScoutWeb.Chain, as: ChainWeb
  alias Explorer.Chain
  alias Explorer.Chain.Cache.BlockNumber

  def getblockreward(conn, params) do
    with {:block_param, {:ok, unsafe_block_number}} <- {:block_param, Map.fetch(params, "blockno")},
         {:ok, block_number} <- ChainWeb.param_to_block_number(unsafe_block_number),
         {:ok, block} <- Chain.number_to_block(block_number) do
      reward = Chain.block_reward(block_number)

      render(conn, :block_reward, block: block, reward: reward)
    else
      {:block_param, :error} ->
        render(conn, :error, error: "Query parameter 'blockno' is required")

      {:error, :invalid} ->
        render(conn, :error, error: "Invalid block number")

      {:error, :not_found} ->
        render(conn, :error, error: "Block does not exist")
    end
  end

  def eth_block_number(conn, params) do
    id = Map.get(params, "id", 1)
    max_block_number = BlockNumber.get_max()

    render(conn, :eth_block_number, number: max_block_number, id: id)
  end
end
