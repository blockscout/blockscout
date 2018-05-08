defmodule Explorer.JSONRPC.Parity do
  @moduledoc """
  Ethereum JSONRPC methods that are only supported by [Parity](https://wiki.parity.io/).
  """

  import Explorer.JSONRPC, only: [config: 1, json_rpc: 2]

  alias Explorer.JSONRPC.Parity.Traces

  def fetch_internal_transactions(transaction_hashes) when is_list(transaction_hashes) do
    with {:ok, responses} <-
           transaction_hashes
           |> Enum.map(&transaction_hash_to_internal_transaction_json/1)
           |> json_rpc(config(:trace_url)) do
      internal_transactions_params =
        responses
        |> responses_to_traces()
        |> Traces.to_elixir()
        |> Traces.elixir_to_params()

      {:ok, internal_transactions_params}
    end
  end

  defp response_to_trace(%{"id" => transaction_hash, "result" => %{"trace" => traces}}) when is_list(traces) do
    traces
    |> Stream.with_index()
    |> Enum.map(fn {trace, index} ->
      Map.merge(trace, %{"index" => index, "transactionHash" => transaction_hash})
    end)
  end

  defp responses_to_traces(responses) when is_list(responses) do
    Enum.flat_map(responses, &response_to_trace/1)
  end

  defp transaction_hash_to_internal_transaction_json(transaction_hash) do
    %{
      "id" => transaction_hash,
      "jsonrpc" => "2.0",
      "method" => "trace_replayTransaction",
      "params" => [transaction_hash, ["trace"]]
    }
  end
end
