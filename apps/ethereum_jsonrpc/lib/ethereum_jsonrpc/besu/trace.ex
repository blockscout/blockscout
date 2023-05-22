defmodule EthereumJSONRPC.Besu.Trace do
  @moduledoc """
  Trace returned by
  [`trace_replayTransaction`](https://openethereum.github.io/JSONRPC-trace-module#trace_replaytransaction).
  """

  alias EthereumJSONRPC.Nethermind.Trace, as: NethermindTrace
  alias EthereumJSONRPC.Nethermind.Trace.{Action, Result}

  def elixir_to_params(elixir) do
    NethermindTrace.elixir_to_params(elixir)
  end

  def to_elixir(%{"blockNumber" => _, "index" => _, "transactionHash" => _, "transactionIndex" => _} = trace)
      when is_map(trace) do
    Enum.into(trace, %{}, &entry_to_elixir/1)
  end

  def to_elixir(trace) do
    NethermindTrace.to_elixir(trace)
  end

  # subtraces is an actual integer in JSON and not hex-encoded
  # traceAddress is a list of actual integers, not a list of hex-encoded
  defp entry_to_elixir({key, _} = entry)
       when key in ~w(subtraces traceAddress transactionHash blockHash type output),
       do: entry

  defp entry_to_elixir({"action" = key, action}) do
    {key, Action.to_elixir(action)}
  end

  defp entry_to_elixir({"blockNumber", block_number} = entry) when is_integer(block_number),
    do: entry

  defp entry_to_elixir({"error", reason} = entry) when is_binary(reason), do: entry

  defp entry_to_elixir({"index", index} = entry) when is_integer(index), do: entry

  defp entry_to_elixir({"revertReason", reason} = entry) when is_binary(reason), do: entry

  defp entry_to_elixir({"result" = key, result}) do
    {key, Result.to_elixir(result)}
  end

  defp entry_to_elixir({"transactionIndex", index} = entry) when is_integer(index), do: entry
end
