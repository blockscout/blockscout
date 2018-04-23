defmodule Explorer.JSONRPC.Receipt do
  @moduledoc """
  Receipts format as returned by
  [`eth_getTransactionReceipt`](https://github.com/ethereum/wiki/wiki/JSON-RPC#eth_gettransactionreceipt).
  """

  alias Explorer.JSONRPC

  # Types

  @type elixir :: %{String.t() => nil}

  @typedoc """
  * `"contractAddress"` - The contract `t:Explorer.JSONRPC.address/0` created, if the transaction was a contract
      creation, otherwise `nil`.
  * `"blockHash"` - `t:Explorer.JSONRPC.hash/0` of the block where `"transactionHash"` was in.
  * `"blockNumber"` - The block number `t:Explorer.JSONRPC.quanity/0`.
  * `"cumulativeGasUsed"` - `t:Explorer.JSONRPC.quantity/0` of gas used when this transaction was executed in the block.
  * `"gasUsed"` - `t:Explorer.JSONRPC.quantity/0` of gas used by this specific transaction alone.
  * `"logs"` - `t:list/0` of log objects, which this transaction generated.
  * `"logsBloom"` - `t:Explorer.JSONRPC.data/0` of 256 Bytes for
      [Bloom filter](https://en.wikipedia.org/wiki/Bloom_filter) for light clients to quickly retrieve related logs.
  * `"root"` - `t:Explorer.JSONRPC.hash/0`  of post-transaction stateroot (pre-Byzantium)
  * `"status"` - `t:Explorer.JSONRPC.quantity/0` of either 1 (success) or 0 (failure) (post-Byzantium)
  * `"transactionHash" - `t:Explorer.JSONRPC.hash/0` the transaction.
  * `"transactionIndex"` - `t:Explorer.JSONRPC.quantity/0` for the transaction index in the block.
  """
  @type t :: %{String.t() => JSONRPC.address() | JSONRPC.data() | JSONRPC.hash() | JSONRPC.quantity() | list | nil}

  # Functions

  @spec elixir_to_params(elixir) :: [map]
  def elixir_to_params(elixir) when is_list(elixir) do
    raise "BOOM"
  end

  @spec to_elixir(t) :: elixir
  def to_elixir(receipt) when is_map(receipt) do
    Enum.into(receipt, %{}, &entry_to_elixir/1)
  end

  ## Private Functions

  # double check that no new keys are being missed by requiring explicit match for passthrough
  # `t:Explorer.JSONRPC.address/0` and `t:Explorer.JSONRPC.hash/0` pass through as `Explorer.Chain` can verify correct
  # hash format
  defp entry_to_elixir({key, _} = entry) when key in ~w(foo), do: entry
end
