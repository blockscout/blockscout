defmodule EthereumJSONRPC.Transaction do
  @moduledoc """
  Transaction format included in the return of
  [`eth_getBlockByHash`](https://github.com/ethereum/wiki/wiki/JSON-RPC#eth_getblockbyhash)
  and [`eth_getBlockByNumber`](https://github.com/ethereum/wiki/wiki/JSON-RPC#eth_getblockbynumber) and returned by
  [`eth_getTransactionByHash`](https://github.com/ethereum/wiki/wiki/JSON-RPC#eth_gettransactionbyhash),
  [`eth_getTransactionByBlockHashAndIndex`](https://github.com/ethereum/wiki/wiki/JSON-RPC#eth_gettransactionbyblockhashandindex),
  and [`eth_getTransactionByBlockNumberAndIndex`](https://github.com/ethereum/wiki/wiki/JSON-RPC#eth_gettransactionbyblocknumberandindex)
  """
  require Logger

  import EthereumJSONRPC, only: [quantity_to_integer: 1, integer_to_quantity: 1, request: 1]

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
   * `"value"` - `t:EthereumJSONRPC.quantity/0` of wei transferred.
   * `"maxPriorityFeePerGas"` - `t:EthereumJSONRPC.quantity/0` of wei to denote max priority fee per unit of gas used. Introduced in [EIP-1559](https://github.com/ethereum/EIPs/blob/master/EIPS/eip-1559.md)
   * `"maxFeePerGas"` - `t:EthereumJSONRPC.quantity/0` of wei to denote max fee per unit of gas used. Introduced in [EIP-1559](https://github.com/ethereum/EIPs/blob/master/EIPS/eip-1559.md)
   * `"type"` - `t:EthereumJSONRPC.quantity/0` denotes transaction type. Introduced in [EIP-1559](https://github.com/ethereum/EIPs/blob/master/EIPS/eip-1559.md)
  """
  @type t :: %{
          String.t() =>
            EthereumJSONRPC.address() | EthereumJSONRPC.hash() | EthereumJSONRPC.quantity() | String.t() | nil
        }

  @type params :: %{
          block_hash: EthereumJSONRPC.hash(),
          block_number: non_neg_integer(),
          from_address_hash: EthereumJSONRPC.address(),
          gas: non_neg_integer(),
          gas_price: non_neg_integer(),
          hash: EthereumJSONRPC.hash(),
          index: non_neg_integer(),
          input: String.t(),
          nonce: non_neg_integer(),
          r: non_neg_integer(),
          s: non_neg_integer(),
          to_address_hash: EthereumJSONRPC.address(),
          v: non_neg_integer(),
          value: non_neg_integer(),
          transaction_index: non_neg_integer(),
          max_priority_fee_per_gas: non_neg_integer(),
          max_fee_per_gas: non_neg_integer(),
          type: non_neg_integer()
        }

  @doc """
  Geth `elixir` can be converted to `params`.  Geth does not supply `"publicKey"` or `"standardV"`, unlike Parity.

      iex> EthereumJSONRPC.Transaction.elixir_to_params(
      ...>   %{
      ...>     "blockHash" => "0x4e3a3754410177e6937ef1f84bba68ea139e8d1a2258c5f85db9f1cd715a1bdd",
      ...>     "blockNumber" => 46147,
      ...>     "from" => "0xa1e4380a3b1f749673e270229993ee55f35663b4",
      ...>     "gas" => 21000,
      ...>     "gasPrice" => 50000000000000,
      ...>     "hash" => "0x5c504ed432cb51138bcf09aa5e8a410dd4a1e204ef84bfed1be16dfba1b22060",
      ...>     "input" => "0x",
      ...>     "nonce" => 0,
      ...>     "r" => 61965845294689009770156372156374760022787886965323743865986648153755601564112,
      ...>     "s" => 31606574786494953692291101914709926755545765281581808821704454381804773090106,
      ...>     "to" => "0x5df9b87991262f6ba471f09758cde1c0fc1de734",
      ...>     "transactionIndex" => 0,
      ...>     "v" => 28,
      ...>     "value" => 31337
      ...>   }
      ...> )
      %{
        block_hash: "0x4e3a3754410177e6937ef1f84bba68ea139e8d1a2258c5f85db9f1cd715a1bdd",
        block_number: 46147,
        from_address_hash: "0xa1e4380a3b1f749673e270229993ee55f35663b4",
        gas: 21000,
        gas_price: 50000000000000,
        hash: "0x5c504ed432cb51138bcf09aa5e8a410dd4a1e204ef84bfed1be16dfba1b22060",
        index: 0,
        input: "0x",
        nonce: 0,
        r: 61965845294689009770156372156374760022787886965323743865986648153755601564112,
        s: 31606574786494953692291101914709926755545765281581808821704454381804773090106,
        to_address_hash: "0x5df9b87991262f6ba471f09758cde1c0fc1de734",
        v: 28,
        value: 31337,
        transaction_index: 0
      }

  """
  @spec elixir_to_params(elixir) :: params

  def elixir_to_params(
        %{
          "blockHash" => block_hash,
          "blockNumber" => block_number,
          "from" => from_address_hash,
          "gas" => gas,
          "hash" => hash,
          "input" => input,
          "nonce" => nonce,
          "r" => r,
          "s" => s,
          "to" => to_address_hash,
          "transactionIndex" => index,
          "v" => v,
          "value" => value,
          "type" => type,
          "maxPriorityFeePerGas" => max_priority_fee_per_gas,
          "maxFeePerGas" => max_fee_per_gas
        } = transaction
      ) do
    result = %{
      block_hash: block_hash,
      block_number: block_number,
      from_address_hash: from_address_hash,
      gas: gas,
      gas_price: max_fee_per_gas,
      hash: hash,
      index: index,
      input: input,
      nonce: nonce,
      r: r,
      s: s,
      to_address_hash: to_address_hash,
      v: v,
      value: value,
      transaction_index: index,
      type: type,
      max_priority_fee_per_gas: max_priority_fee_per_gas,
      max_fee_per_gas: max_fee_per_gas
    }

    if transaction["creates"] do
      Map.put(result, :created_contract_address_hash, transaction["creates"])
    else
      result
    end
  end

  def elixir_to_params(
        %{
          "blockHash" => block_hash,
          "blockNumber" => block_number,
          "from" => from_address_hash,
          "gas" => gas,
          "gasPrice" => gas_price,
          "hash" => hash,
          "input" => input,
          "nonce" => nonce,
          "r" => r,
          "s" => s,
          "to" => to_address_hash,
          "transactionIndex" => index,
          "v" => v,
          "value" => value,
          "type" => type
        } = transaction
      ) do
    result = %{
      block_hash: block_hash,
      block_number: block_number,
      from_address_hash: from_address_hash,
      gas: gas,
      gas_price: gas_price,
      hash: hash,
      index: index,
      input: input,
      nonce: nonce,
      r: r,
      s: s,
      to_address_hash: to_address_hash,
      v: v,
      value: value,
      transaction_index: index,
      type: type
    }

    if transaction["creates"] do
      Map.put(result, :created_contract_address_hash, transaction["creates"])
    else
      result
    end
  end

  def elixir_to_params(
        %{
          "blockHash" => block_hash,
          "blockNumber" => block_number,
          "from" => from_address_hash,
          "gas" => gas,
          "gasPrice" => gas_price,
          "hash" => hash,
          "input" => input,
          "nonce" => nonce,
          "r" => r,
          "s" => s,
          "to" => to_address_hash,
          "transactionIndex" => index,
          "v" => v,
          "value" => value,
          "type" => type,
          "maxPriorityFeePerGas" => max_priority_fee_per_gas,
          "maxFeePerGas" => max_fee_per_gas
        } = transaction
      ) do
    result = %{
      block_hash: block_hash,
      block_number: block_number,
      from_address_hash: from_address_hash,
      gas: gas,
      gas_price: gas_price,
      hash: hash,
      index: index,
      input: input,
      nonce: nonce,
      r: r,
      s: s,
      to_address_hash: to_address_hash,
      v: v,
      value: value,
      transaction_index: index,
      type: type,
      max_priority_fee_per_gas: max_priority_fee_per_gas,
      max_fee_per_gas: max_fee_per_gas
    }

    if transaction["creates"] do
      Map.put(result, :created_contract_address_hash, transaction["creates"])
    else
      result
    end
  end

  def elixir_to_params(
        %{
          "blockHash" => block_hash,
          "blockNumber" => block_number,
          "from" => from_address_hash,
          "gas" => gas,
          "gasPrice" => gas_price,
          "hash" => hash,
          "input" => input,
          "nonce" => nonce,
          "r" => r,
          "s" => s,
          "to" => to_address_hash,
          "transactionIndex" => index,
          "v" => v,
          "value" => value
        } = transaction
      ) do
    result = %{
      block_hash: block_hash,
      block_number: block_number,
      from_address_hash: from_address_hash,
      gas: gas,
      gas_price: gas_price,
      hash: hash,
      index: index,
      input: input,
      nonce: nonce,
      r: r,
      s: s,
      to_address_hash: to_address_hash,
      v: v,
      value: value,
      transaction_index: index
    }

    if transaction["creates"] do
      Map.put(result, :created_contract_address_hash, transaction["creates"])
    else
      result
    end
  end

  def elixir_to_params(
        %{
          nil => _
        } = transaction
      ) do
    transaction
    |> Map.delete(nil)
    |> elixir_to_params()
  end

  @doc """
  Extracts `t:EthereumJSONRPC.hash/0` from transaction `params`

      iex> EthereumJSONRPC.Transaction.params_to_hash(
      ...>   %{
      ...>     block_hash: "0xe52d77084cab13a4e724162bcd8c6028e5ecfaa04d091ee476e96b9958ed6b47",
      ...>     block_number: 34,
      ...>     gas: 4700000,
      ...>     gas_price: 100000000000,
      ...>     hash: "0x3a3eb134e6792ce9403ea4188e5e79693de9e4c94e499db132be086400da79e6",
      ...>     index: 0,
      ...>     input: "0x6060604052341561000f57600080fd5b336000806101000a81548173ffffffffffffffffffffffffffffffffffffffff021916908373ffffffffffffffffffffffffffffffffffffffff1602179055506102db8061005e6000396000f300606060405260043610610062576000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff1680630900f01014610067578063445df0ac146100a05780638da5cb5b146100c9578063fdacd5761461011e575b600080fd5b341561007257600080fd5b61009e600480803573ffffffffffffffffffffffffffffffffffffffff16906020019091905050610141565b005b34156100ab57600080fd5b6100b3610224565b6040518082815260200191505060405180910390f35b34156100d457600080fd5b6100dc61022a565b604051808273ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff16815260200191505060405180910390f35b341561012957600080fd5b61013f600480803590602001909190505061024f565b005b60008060009054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff163373ffffffffffffffffffffffffffffffffffffffff161415610220578190508073ffffffffffffffffffffffffffffffffffffffff1663fdacd5766001546040518263ffffffff167c010000000000000000000000000000000000000000000000000000000002815260040180828152602001915050600060405180830381600087803b151561020b57600080fd5b6102c65a03f1151561021c57600080fd5b5050505b5050565b60015481565b6000809054906101000a900473ffffffffffffffffffffffffffffffffffffffff1681565b6000809054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff163373ffffffffffffffffffffffffffffffffffffffff1614156102ac57806001819055505b505600a165627a7a72305820a9c628775efbfbc17477a472413c01ee9b33881f550c59d21bee9928835c854b0029",
      ...>     nonce: 0,
      ...>     r: "0xAD3733DF250C87556335FFE46C23E34DBAFFDE93097EF92F52C88632A40F0C75",
      ...>     s: "0x72caddc0371451a58de2ca6ab64e0f586ccdb9465ff54e1c82564940e89291e3",
      ...>     v: "0x8d",
      ...>     value: 0
      ...>   }
      ...> )
      "0x3a3eb134e6792ce9403ea4188e5e79693de9e4c94e499db132be086400da79e6"

  """
  def params_to_hash(%{hash: hash}), do: hash

  @doc """
  Decodes the stringly typed numerical fields to `t:non_neg_integer/0`.

  Pending transactions have a `nil` `"blockHash"`, `"blockNumber"`, and `"transactionIndex"` because those fields are
  related to the block the transaction is collated in.

    iex> EthereumJSONRPC.Transaction.to_elixir(
    ...>   %{
    ...>     "blockHash" => nil,
    ...>     "blockNumber" => nil,
    ...>     "chainId" => "0x4d",
    ...>     "condition" => nil,
    ...>     "creates" => nil,
    ...>     "from" => "0x40aa34fb35ef0804a41c2b4be7d3e3d65c7f6d5c",
    ...>     "gas" => "0xcf08",
    ...>     "gasPrice" => "0x0",
    ...>     "hash" => "0x6b80a90c958fb5791a070929379ed6eb7a33ecdf9f9cafcada2f6803b3f25ec3",
    ...>     "input" => "0x",
    ...>     "nonce" => "0x77",
    ...>     "publicKey" => "0xd0bf6fb4ce4ada1ddfb754b98cd89dc61c3ff143a260cf1712517af2af602b699aab554a2532051e5ba205eb41068c3423f23acde87313211750a8cbf862170e",
    ...>     "r" => "0x3cfc2a34c2e4e09913934a5ade1055206e39b1e34fabcfcc820f6f70c740944c",
    ...>     "raw" => "0xf868778082cf08948e854802d695269a6f1f3fcabb2111d2f5a0e6f9880de0b6b3a76400008081bea03cfc2a34c2e4e09913934a5ade1055206e39b1e34fabcfcc820f6f70c740944ca014cf6f15b5855f9b68eb58c95f76603a54b2ca612f921bb8d424de11bf085390",
    ...>     "s" => "0x14cf6f15b5855f9b68eb58c95f76603a54b2ca612f921bb8d424de11bf085390",
    ...>     "standardV" => "0x1",
    ...>     "to" => "0x8e854802d695269a6f1f3fcabb2111d2f5a0e6f9",
    ...>     "transactionIndex" => nil,
    ...>     "v" => "0xbe",
    ...>     "value" => "0xde0b6b3a7640000"
    ...>   }
    ...> )
    %{
      "blockHash" => nil,
      "blockNumber" => nil,
      "chainId" => 77,
      "condition" => nil,
      "creates" => nil,
      "from" => "0x40aa34fb35ef0804a41c2b4be7d3e3d65c7f6d5c",
      "gas" => 53000,
      "gasPrice" => 0,
      "hash" => "0x6b80a90c958fb5791a070929379ed6eb7a33ecdf9f9cafcada2f6803b3f25ec3",
      "input" => "0x",
      "nonce" => 119,
      "publicKey" => "0xd0bf6fb4ce4ada1ddfb754b98cd89dc61c3ff143a260cf1712517af2af602b699aab554a2532051e5ba205eb41068c3423f23acde87313211750a8cbf862170e",
      "r" => 27584307671108667307432650922507113611469948945973084068788107666229588694092,
      "raw" => "0xf868778082cf08948e854802d695269a6f1f3fcabb2111d2f5a0e6f9880de0b6b3a76400008081bea03cfc2a34c2e4e09913934a5ade1055206e39b1e34fabcfcc820f6f70c740944ca014cf6f15b5855f9b68eb58c95f76603a54b2ca612f921bb8d424de11bf085390",
      "s" => 9412760993194218539611435541875082818858943210434840876051960418568625476496,
      "standardV" => 1,
      "to" => "0x8e854802d695269a6f1f3fcabb2111d2f5a0e6f9",
      "transactionIndex" => nil,
      "v" => 190,
      "value" => 1000000000000000000
    }

  """
  def to_elixir(transaction) when is_map(transaction) do
    Enum.into(transaction, %{}, &entry_to_elixir/1)
  end

  def to_elixir(transaction) when is_binary(transaction) do
    #    Logger.warn(["Fetched transaction is not full: ", transaction])

    nil
  end

  def eth_call_request(id, block_number, data, to, from, gas, gas_price, value) do
    block =
      case block_number do
        nil -> "latest"
        block_number -> integer_to_quantity(block_number)
      end

    request(%{
      id: id,
      method: "eth_call",
      params: [%{to: to, from: from, data: data, gas: gas, gasPrice: gas_price, value: value}, block]
    })
  end

  # double check that no new keys are being missed by requiring explicit match for passthrough
  # `t:EthereumJSONRPC.address/0` and `t:EthereumJSONRPC.hash/0` pass through as `Explorer.Chain` can verify correct
  # hash format
  #
  # "txType": to avoid FunctionClauseError when indexing Wanchain
  defp entry_to_elixir({key, value})
       when key in ~w(blockHash condition creates from hash input jsonrpc publicKey raw to txType),
       do: {key, value}

  # specific to Nethermind client
  defp entry_to_elixir({"data", value}),
    do: {"input", value}

  defp entry_to_elixir({key, quantity})
       when key in ~w(gas gasPrice nonce r s standardV v value type maxPriorityFeePerGas maxFeePerGas) and
              quantity != nil do
    {key, quantity_to_integer(quantity)}
  end

  # as always ganache has it's own vision on JSON RPC standard
  defp entry_to_elixir({key, nil}) when key in ~w(r s v) do
    {key, 0}
  end

  # quantity or nil for pending
  defp entry_to_elixir({key, quantity_or_nil}) when key in ~w(blockNumber transactionIndex) do
    elixir =
      case quantity_or_nil do
        nil -> nil
        quantity -> quantity_to_integer(quantity)
      end

    {key, elixir}
  end

  # chainId is *sometimes* nil
  defp entry_to_elixir({"chainId" = key, chain_id}) do
    case chain_id do
      nil -> {key, chain_id}
      _ -> {key, quantity_to_integer(chain_id)}
    end
  end

  defp entry_to_elixir(_) do
    {nil, nil}
  end
end
