defmodule Explorer.Chain.Cache.NetVersion do
  @moduledoc """
  Caches chain version.
  """

  require Logger

  use Explorer.Chain.MapCache,
    name: :net_version,
    key: :version

  defp handle_fallback(:version) do
    case EthereumJSONRPC.fetch_net_version(Application.get_env(:explorer, :json_rpc_named_arguments)) do
      {:ok, value} ->
        {:update, value}

      {:error, reason} ->
        Logger.debug([
          "Couldn't fetch net_version, reason: #{inspect(reason)}"
        ])

        {:return, nil}
    end
  end

  defp handle_fallback(_key), do: {:return, nil}
end
