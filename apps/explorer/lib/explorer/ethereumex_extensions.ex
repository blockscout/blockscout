defmodule Explorer.EthereumexExtensions do
  @moduledoc """
    Downloads the trace for a Transaction from a node.
  """

  alias Ethereumex.HttpClient

  @dialyzer {:nowarn_function, trace_transaction: 1}
  def trace_transaction(hash) do
    params = [hash, ["trace"]]
    {:ok, trace} = HttpClient.request("trace_replayTransaction", params, [])
    trace
  end
end
