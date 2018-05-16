defmodule EthereumJSONRPC.Transaction do
  @moduledoc """
  Transaction format included in the return of
  [`eth_getBlockByHash`](https://github.com/ethereum/wiki/wiki/JSON-RPC#eth_getblockbyhash)
  and [`eth_getBlockByNumber`](https://github.com/ethereum/wiki/wiki/JSON-RPC#eth_getblockbynumber) and returned by
  [`eth_getTransactionByHash`](https://github.com/ethereum/wiki/wiki/JSON-RPC#eth_gettransactionbyhash),
  [`eth_getTransactionByBlockHashAndIndex`](https://github.com/ethereum/wiki/wiki/JSON-RPC#eth_gettransactionbyblockhashandindex),
  and [`eth_getTransactionByBlockNumberAndIndex`](https://github.com/ethereum/wiki/wiki/JSON-RPC#eth_gettransactionbyblocknumberandindex)
  """

  import EthereumJSONRPC, only: [quantity_to_integer: 1]

  alias EthereumJSONRPC

  @type elixir :: %{
          String.t() => EthereumJSONRPC.address() | EthereumJSONRPC.hash() | String.t() | non_neg_integer() | nil
        }

  @typedoc """
   * `"blockHash"` - `t:EthereumJSONRPC.hash/0` of the block this transaction is in.  `nil` when transaction is
     pending.
   * `"blockNumber"` - `t:EthereumJSONRPC.quantity/0` for the block number this transaction is in.  `nil` when
     transaction is pending.
   * `"chainId"` - the chain on which the transaction exists.
   * `"condition"` - UNKNOWN
   * `"creates"` - `t:EthereumJSONRPC.address/0` of the created contract, if the transaction creates a contract.
   * `"from"` - `t:EthereumJSONRPC.address/0` of the sender.
   * `"gas"` - `t:EthereumJSONRPC.quantity/0` of gas provided by the sender.  This is the max gas that may be used.
     `gas * gasPrice` is the max fee in wei that the sender is willing to pay for the transaction to be executed.
   * `"gasPrice"` - `t:EthereumJSONRPC.quantity/0` of wei to pay per unit of gas used.
   * `"hash"` - `t:EthereumJSONRPC.hash/0` of the transaction
   * `"input"` - `t:EthereumJSONRPC.data/0` sent along with the transaction, such as input to the contract.
   * `"nonce"` - `t:EthereumJSONRPC.quantity/0` of transactions made by the sender prior to this one.
   * `"publicKey"` - `t:EthereumJSONRPC.hash/0` of the public key of the signer.
   * `"r"` - `t:EthereumJSONRPC.quantity/0` for the R field of the signature.
   * `"raw"` - Raw transaction `t:EthereumJSONRPC.data/0`
   * `"standardV"` - `t:EthereumJSONRPC.quantity/0` for the standardized V (`0` or `1`) field of the signature.
   * `"to"` - `t:EthereumJSONRPC.address/0` of the receiver.  `nil` when it is a contract creation transaction.
   * `"transactionIndex"` - `t:EthereumJSONRPC.quantity/0` for the index of the transaction in the block.  `nil` when
     transaction is pending.
   * `"v"` - `t:EthereumJSONRPC.quantity/0` for the V field of the signature.
   * `"value"` - `t:EthereumJSONRPC.quantity/0` of wei transfered
  """
  @type t :: %{
          String.t() =>
            EthereumJSONRPC.address() | EthereumJSONRPC.hash() | EthereumJSONRPC.quantity() | String.t() | nil
        }

  @type params :: %{
          block_hash: EthereumJSONRPC.hash(),
          from_address_hash: EthereumJSONRPC.address(),
          gas: non_neg_integer(),
          gas_price: non_neg_integer(),
          hash: EthereumJSONRPC.hash(),
          index: non_neg_integer(),
          input: String.t(),
          nonce: non_neg_integer(),
          public_key: String.t(),
          r: non_neg_integer(),
          s: non_neg_integer(),
          standard_v: 0 | 1,
          to_address_hash: EthereumJSONRPC.address(),
          v: non_neg_integer(),
          value: non_neg_integer()
        }

  @spec elixir_to_params(elixir) :: params
  def elixir_to_params(%{
        "blockHash" => block_hash,
        "from" => from_address_hash,
        "gas" => gas,
        "gasPrice" => gas_price,
        "hash" => hash,
        "input" => input,
        "nonce" => nonce,
        "publicKey" => public_key,
        "r" => r,
        "s" => s,
        "standardV" => standard_v,
        "to" => to_address_hash,
        "transactionIndex" => index,
        "v" => v,
        "value" => value
      }) do
    %{
      block_hash: block_hash,
      from_address_hash: from_address_hash,
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
      to_address_hash: to_address_hash,
      v: v,
      value: value
    }
  end

  @doc """
  Extracts `t:EthereumJSONRPC.hash/0` from transaction `params`

      iex> EthereumJSONRPC.Transaction.params_to_hash(
      ...>   %{
      ...>     block_hash: "0xe52d77084cab13a4e724162bcd8c6028e5ecfaa04d091ee476e96b9958ed6b47",
      ...>     gas: 4700000,
      ...>     gas_price: 100000000000,
      ...>     hash: "0x3a3eb134e6792ce9403ea4188e5e79693de9e4c94e499db132be086400da79e6",
      ...>     index: 0,
      ...>     input: "0x6060604052341561000f57600080fd5b336000806101000a81548173ffffffffffffffffffffffffffffffffffffffff021916908373ffffffffffffffffffffffffffffffffffffffff1602179055506102db8061005e6000396000f300606060405260043610610062576000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff1680630900f01014610067578063445df0ac146100a05780638da5cb5b146100c9578063fdacd5761461011e575b600080fd5b341561007257600080fd5b61009e600480803573ffffffffffffffffffffffffffffffffffffffff16906020019091905050610141565b005b34156100ab57600080fd5b6100b3610224565b6040518082815260200191505060405180910390f35b34156100d457600080fd5b6100dc61022a565b604051808273ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff16815260200191505060405180910390f35b341561012957600080fd5b61013f600480803590602001909190505061024f565b005b60008060009054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff163373ffffffffffffffffffffffffffffffffffffffff161415610220578190508073ffffffffffffffffffffffffffffffffffffffff1663fdacd5766001546040518263ffffffff167c010000000000000000000000000000000000000000000000000000000002815260040180828152602001915050600060405180830381600087803b151561020b57600080fd5b6102c65a03f1151561021c57600080fd5b5050505b5050565b60015481565b6000809054906101000a900473ffffffffffffffffffffffffffffffffffffffff1681565b6000809054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff163373ffffffffffffffffffffffffffffffffffffffff1614156102ac57806001819055505b505600a165627a7a72305820a9c628775efbfbc17477a472413c01ee9b33881f550c59d21bee9928835c854b0029",
      ...>     nonce: 0,
      ...>     public_key: "0xe5d196ad4ceada719d9e592f7166d0c75700f6eab2e3c3de34ba751ea786527cb3f6eb96ad9fdfdb9989ff572df50f1c42ef800af9c5207a38b929aff969b5c9",
      ...>     r: "0xAD3733DF250C87556335FFE46C23E34DBAFFDE93097EF92F52C88632A40F0C75",
      ...>     s: "0x72caddc0371451a58de2ca6ab64e0f586ccdb9465ff54e1c82564940e89291e3",
      ...>     standard_v: 0,
      ...>     v: "0x8d",
      ...>     value: 0
      ...>   }
      ...> )
      "0x3a3eb134e6792ce9403ea4188e5e79693de9e4c94e499db132be086400da79e6"

  """
  def params_to_hash(%{hash: hash}), do: hash

  @doc """
  Decodes the stringly typed numerical fields to `t:non_neg_integer/0`.
  """
  def to_elixir(transaction) when is_map(transaction) do
    Enum.into(transaction, %{}, &entry_to_elixir/1)
  end

  # double check that no new keys are being missed by requiring explicit match for passthrough
  # `t:EthereumJSONRPC.address/0` and `t:EthereumJSONRPC.hash/0` pass through as `Explorer.Chain` can verify correct
  # hash format
  # v passes through because they exceed postgres integer limits
  defp entry_to_elixir({key, value})
       when key in ~w(blockHash condition creates from hash input jsonrpc publicKey raw to v),
       do: {key, value}

  defp entry_to_elixir({key, quantity})
       when key in ~w(blockNumber gas gasPrice nonce r s standardV transactionIndex value) do
    {key, quantity_to_integer(quantity)}
  end

  # chainId is *sometimes* nil
  defp entry_to_elixir({"chainId" = key, chainId}) do
    case chainId do
      nil -> {key, chainId}
      _ -> {key, quantity_to_integer(chainId)}
    end
  end
end
