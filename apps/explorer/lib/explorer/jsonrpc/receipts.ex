defmodule Explorer.JSONRPC.Receipts do
  @moduledoc """
  Receipts format as returned by
  [`eth_getTransactionReceipt`](https://github.com/ethereum/wiki/wiki/JSON-RPC#eth_gettransactionreceipt) from batch
  requests.
  """

  alias Explorer.JSONRPC.Receipt

  # Types

  @type elixir :: [Receipt.elixir()]
  @type t :: [Receipt.t()]

  # Functions

  @spec elixir_to_params(elixir) :: [map]
  def elixir_to_params(elixir) when is_list(elixir) do
    Enum.map(elixir, &Receipt.elixir_to_params/1)
  end

  @spec to_elixir(t) :: elixir
  def to_elixir(receipts) when is_list(receipts) do
    Enum.map(receipts, &Receipt.to_elixir/1)
  end
end
