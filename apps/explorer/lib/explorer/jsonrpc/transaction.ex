defmodule Explorer.JSONRPC.Transaction do
  @moduledoc """
  Transaction format included in the return of
  [`eth_getBlockByHash`](https://github.com/ethereum/wiki/wiki/JSON-RPC#eth_getblockbyhash)
  and [`eth_getBlockByNumber`](https://github.com/ethereum/wiki/wiki/JSON-RPC#eth_getblockbynumber) and returned by
  [`eth_getTransactionByHash`](https://github.com/ethereum/wiki/wiki/JSON-RPC#eth_gettransactionbyhash),
  [`eth_getTransactionByBlockHashAndIndex`](https://github.com/ethereum/wiki/wiki/JSON-RPC#eth_gettransactionbyblockhashandindex),
  and [`eth_getTransactionByBlockNumberAndIndex`](https://github.com/ethereum/wiki/wiki/JSON-RPC#eth_gettransactionbyblocknumberandindex)
  """

  import Explorer.JSONRPC, only: [quantity_to_integer: 1]

  alias Explorer.JSONRPC

  # Types

  @typedoc """
  * `"blockHash"` - `t:Explorer.JSONRPC.hash/0` of the block this transaction is in.  `nil` when transaction is pending.
  * `"blockNumber"` - `t:Explorer.JSONRPC.quantity/0` for the block number this transaction is in.  `nil` when
      transaction is pending.
  * `"from"` - `t:Explorer.JSONRPC.address/0` of the sender.
  * `"gas"` - `t:Explorer.JSONRPC.quantity/0` of gas provided by the sender.  This is the max gas that may be used.
      `gas * gasPrice` is the max fee in wei that the sender is willing to pay for the transaction to be executed.
  * `"gasPrice"` - `t:Explorer.JSONRPC.quantity/0` of wei to pay per unit of gas used.
  * `"hash"` - `t:Explorer.JSONRPC.hash/0` of the transaction
  * `"input"` - `t:Explorer.JSONRPC.data/0` sent along with the transaction, such as input to the contract.
  * `"nonce"` - `t:Explorer.JSONRPC.quantity/0` of transactions made by the sender prior to this one.
  * `"to"` - `t:Explorer.JSONRPC.address/0` of the receiver.  `nil` when it is a contract creation transaction.
  * `"transactionIndex"` - `t:Explorer.JSONRPC.quantity/0` for the index of the transaction in the block.  `nil` when
      transaction is pending.
  * `"value"` - `t:Explorer.JSONRPC.quantity/0` of wei transfered
  """
  @type t :: %{String.t() => JSONRPC.address() | JSONRPC.hash() | JSONRPC.quantity() | nil}

  # Functions

  def elixir_to_params(%{
        "gas" => gas,
        "gasPrice" => gas_price,
        "hash" => hash,
        "input" => input,
        "nonce" => nonce,
        "publicKey" => public_key,
        "r" => r,
        "s" => s,
        "standardV" => standard_v,
        "transactionIndex" => index,
        "v" => v,
        "value" => value
      }) do
    %{
      gas: gas,
      gas_price: gas_price,
      hash: hash,
      index: index,
      input: input,
      nonce: nonce,
      public_key: public_key,
      r: r,
      s: s,
      standard_v: standard_v,
      v: v,
      value: value
    }
  end

  def params_to_hash(%{"hash" => hash}), do: hash

  @doc """
  Decodes the stringly typed numerical fields to `t:non_neg_integer/0`.
  """
  def to_elixir(transaction) when is_map(transaction) do
    Enum.into(transaction, %{}, &to_elixir/1)
  end

  # double check that no new keys are being missed by requiring explicit match for passthrough
  # `t:Explorer.JSONRPC.address/0` and `t:Explorer.JSONRPC.hash/0` pass through as `Explorer.Chain` can verify correct
  # hash format
  def to_elixir({key, value}) when key in ~w(blockHash from hash input jsonrpc), do: {key, value}

  def to_elixir({key, quantity}) when key in ~w(blockNumber gas gasPrice nonce transactionIndex value) do
    {key, quantity_to_integer(quantity)}
  end
end
