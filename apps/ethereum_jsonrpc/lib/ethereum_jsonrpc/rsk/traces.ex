defmodule EthereumJSONRPC.RSK.Traces do
  @moduledoc """
  Traces returned by
  [`trace_block`](https://dev.rootstock.io/rsk/node/architecture/json-rpc/#json-rpc-supported).
  """

  alias EthereumJSONRPC.RSK.Trace

  def elixir_to_params(elixir) when is_list(elixir) do
    Enum.map(elixir, &Trace.elixir_to_params/1)
  end

  def to_elixir(traces) when is_list(traces) do
    Enum.map(traces, &Trace.to_elixir/1)
  end
end
