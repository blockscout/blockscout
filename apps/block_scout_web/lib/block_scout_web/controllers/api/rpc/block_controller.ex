defmodule BlockScoutWeb.API.RPC.BlockController do
  use BlockScoutWeb, :controller

  alias Explorer.Chain
  alias BlockScoutWeb.Chain, as: ChainWeb

  def getblockreward(conn, params) do
    with {:block_param, {:ok, unsafe_block_number}} <- {:block_param, Map.fetch(params, "blockno")},
         {:ok, block_number} <- ChainWeb.param_to_block_number(unsafe_block_number),
         block_options = [necessity_by_association: %{transactions: :optional}],
         {:ok, block} <- Chain.number_to_block(block_number, block_options) do
      reward = Chain.block_reward(block)

      render(conn, :block_reward, block: block, reward: reward)
    else
      {:block_param, :error} ->
        conn
        |> put_status(400)
        |> render(:error, error: "Query parameter 'blockno' is required")

      {:error, :invalid} ->
        conn
        |> put_status(400)
        |> render(:error, error: "Invalid block number")

      {:error, :not_found} ->
        conn
        |> put_status(404)
        |> render(:error, error: "Block does not exist")
    end
  end
end
