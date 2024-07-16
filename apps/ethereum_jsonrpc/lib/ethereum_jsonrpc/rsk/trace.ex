defmodule EthereumJSONRPC.RSK.Trace do
  @moduledoc """
  Trace returned by
  [`trace_block`](https://dev.rootstock.io/rsk/node/architecture/json-rpc/#json-rpc-supported).
  """

  alias EthereumJSONRPC.Besu.Trace, as: BesuTrace
  alias EthereumJSONRPC.Nethermind.Trace, as: NethermindTrace

  def elixir_to_params(elixir) do
    NethermindTrace.elixir_to_params(elixir)
  end

  def to_elixir(trace) do
    {transaction_index, trace_no_tp} = Map.pop(trace, "transactionPosition")

    trace_no_tp
    |> Map.put("transactionIndex", transaction_index)
    |> BesuTrace.to_elixir()
  end
end
