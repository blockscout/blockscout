defmodule EthereumJSONRPC.Nethermind.Traces do
  @moduledoc """
  Trace returned by
  [`trace_replayTransaction`](https://openethereum.github.io/JSONRPC-trace-module#trace_replaytransaction).
  """

  alias EthereumJSONRPC.Nethermind.Trace

  def elixir_to_params(elixir) when is_list(elixir) do
    Enum.map(elixir, &Trace.elixir_to_params/1)
  end

  def to_elixir(traces) when is_list(traces) do
    Enum.map(traces, &Trace.to_elixir/1)
  end
end
