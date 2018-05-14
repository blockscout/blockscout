defmodule EthereumJSONRPC.Logs do
  @moduledoc """
  Collection of logs included in return from
  [`eth_getTransactionReceipt`](https://github.com/ethereum/wiki/wiki/JSON-RPC#eth_gettransactionreceipt).
  """

  alias EthereumJSONRPC.Log

  @type elixir :: [Log.elixir()]
  @type t :: [Log.t()]

  @spec elixir_to_params(elixir) :: [map]
  def elixir_to_params(elixir) when is_list(elixir) do
    Enum.map(elixir, &Log.elixir_to_params/1)
  end

  @spec to_elixir(t) :: elixir
  def to_elixir(logs) when is_list(logs) do
    Enum.map(logs, &Log.to_elixir/1)
  end
end
