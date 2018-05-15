defmodule EthereumJSONRPC.Parity.Traces do
  @moduledoc """
  Trace returned by
  [`trace_replayTransaction`](https://wiki.parity.io/JSONRPC-trace-module.html#trace_replaytransaction), which is an
  extension to the Ethereum JSONRPC standard that is only supported by [Parity](https://wiki.parity.io/).
  """

  alias EthereumJSONRPC.Parity.Trace

  def elixir_to_params(elixir) when is_list(elixir) do
    Enum.map(elixir, &Trace.elixir_to_params/1)
  end

  def to_elixir(traces) when is_list(traces) do
    Enum.map(traces, &Trace.to_elixir/1)
  end
end
