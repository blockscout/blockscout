defmodule Explorer.Chain.Cache.OptimismFinalizationPeriod do
  @moduledoc """
  Caches Optimism Finalization period.
  """

  require Logger

  use Explorer.Chain.MapCache,
    name: :optimism_finalization_period,
    key: :period

  import EthereumJSONRPC, only: [json_rpc: 2, quantity_to_integer: 1]

  alias EthereumJSONRPC.Contract
  alias Indexer.Fetcher.Optimism
  alias Indexer.Fetcher.Optimism.OutputRoot

  defp handle_fallback(:period) do
    optimism_l1_rpc = Application.get_all_env(:indexer)[Optimism][:optimism_l1_rpc]
    output_oracle = Application.get_all_env(:indexer)[OutputRoot][:output_oracle]

    # call FINALIZATION_PERIOD_SECONDS() public getter of L2OutputOracle contract on L1
    request = Contract.eth_call_request("0xf4daa291", output_oracle, 0, nil, nil)

    case json_rpc(request, json_rpc_named_arguments(optimism_l1_rpc)) do
      {:ok, value} ->
        {:update, quantity_to_integer(value)}

      {:error, reason} ->
        Logger.debug([
          "Couldn't fetch Optimism finalization period, reason: #{inspect(reason)}"
        ])

        {:return, nil}
    end
  end

  defp handle_fallback(_key), do: {:return, nil}

  defp json_rpc_named_arguments(optimism_l1_rpc) do
    [
      transport: EthereumJSONRPC.HTTP,
      transport_options: [
        http: EthereumJSONRPC.HTTP.Tesla,
        urls: [optimism_l1_rpc],
        http_options: [
          recv_timeout: :timer.minutes(10),
          timeout: :timer.minutes(10),
          pool: :ethereum_jsonrpc
        ]
      ]
    ]
  end
end
