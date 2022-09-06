defmodule BlockScoutWeb.API.RPC.BlockController do
  use BlockScoutWeb, :controller

  alias BlockScoutWeb.Chain, as: ChainWeb
  alias Explorer.Chain
  alias Explorer.Chain.Cache.BlockNumber

  def getblocknobytime(conn, params) do
    from_api = true

    with {:timestamp_param, {:ok, unsafe_timestamp}} <- {:timestamp_param, Map.fetch(params, "timestamp")},
         {:closest_param, {:ok, unsafe_closest}} <- {:closest_param, Map.fetch(params, "closest")},
         {:ok, timestamp} <- ChainWeb.param_to_block_timestamp(unsafe_timestamp),
         {:ok, closest} <- ChainWeb.param_to_block_closest(unsafe_closest),
         {:ok, block_number} <- Chain.timestamp_to_block_number(timestamp, closest, from_api) do
      render(conn, block_number: block_number)
    else
      {:timestamp_param, :error} ->
        render(conn, :error, error: "Query parameter 'timestamp' is required")

      {:closest_param, :error} ->
        render(conn, :error, error: "Query parameter 'closest' is required")

      {:error, :invalid_timestamp} ->
        render(conn, :error, error: "Invalid `timestamp` param")

      {:error, :invalid_closest} ->
        render(conn, :error, error: "Invalid `closest` param")

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
