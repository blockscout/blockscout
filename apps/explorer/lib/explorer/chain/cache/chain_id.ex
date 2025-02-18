defmodule Explorer.Chain.Cache.ChainId do
  @moduledoc """
  Caches chain ID.
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
