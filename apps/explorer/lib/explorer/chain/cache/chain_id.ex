defmodule Explorer.Chain.Cache.ChainId do
  @moduledoc """
    Caches the blockchain's chain ID to reduce repeated JSON-RPC calls.

    The chain ID is fetched from the node using `eth_chainId` JSON-RPC call when the cache is empty.

    This helps improve performance by avoiding repeated RPC calls for this frequently needed value.
  """

  require Logger

  use Explorer.Chain.MapCache,
    name: :chain_id,
    key: :id

  defp handle_fallback(:id) do
    case EthereumJSONRPC.fetch_chain_id(Application.get_env(:explorer, :json_rpc_named_arguments)) do
      {:ok, value} ->
        {:update, value}

      {:error, reason} ->
        Logger.debug([
          "Couldn't fetch eth_chainId, reason: #{inspect(reason)}"
        ])

        {:return, nil}
    end
  end

  defp handle_fallback(_key), do: {:return, nil}
end
