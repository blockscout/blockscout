defmodule EthereumJSONRPC.Parity.Trace do
  @moduledoc """
  Trace returned by
  [`trace_replayTransaction`](https://wiki.parity.io/JSONRPC-trace-module.html#trace_replaytransaction), which is an
  extension to the Ethereum JSONRPC standard that is only supported by [Parity](https://wiki.parity.io/).
  """

  alias EthereumJSONRPC.Parity.Trace.{Action, Result}

  @doc """
  Create type traces are generated when a contract is created.

      iex> EthereumJSONRPC.Parity.Trace.elixir_to_params(
      ...>   %{
      ...>     "action" => %{
      ...>       "from" => "0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca",
      ...>       "gas" => 4597044,
      ...>       "init" => "0x6060604052341561000f57600080fd5b336000806101000a81548173ffffffffffffffffffffffffffffffffffffffff021916908373ffffffffffffffffffffffffffffffffffffffff1602179055506102db8061005e6000396000f300606060405260043610610062576000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff1680630900f01014610067578063445df0ac146100a05780638da5cb5b146100c9578063fdacd5761461011e575b600080fd5b341561007257600080fd5b61009e600480803573ffffffffffffffffffffffffffffffffffffffff16906020019091905050610141565b005b34156100ab57600080fd5b6100b3610224565b6040518082815260200191505060405180910390f35b34156100d457600080fd5b6100dc61022a565b604051808273ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff16815260200191505060405180910390f35b341561012957600080fd5b61013f600480803590602001909190505061024f565b005b60008060009054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff163373ffffffffffffffffffffffffffffffffffffffff161415610220578190508073ffffffffffffffffffffffffffffffffffffffff1663fdacd5766001546040518263ffffffff167c010000000000000000000000000000000000000000000000000000000002815260040180828152602001915050600060405180830381600087803b151561020b57600080fd5b6102c65a03f1151561021c57600080fd5b5050505b5050565b60015481565b6000809054906101000a900473ffffffffffffffffffffffffffffffffffffffff1681565b6000809054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff163373ffffffffffffffffffffffffffffffffffffffff1614156102ac57806001819055505b505600a165627a7a72305820a9c628775efbfbc17477a472413c01ee9b33881f550c59d21bee9928835c854b0029",
      ...>       "value" => 0
      ...>     },
      ...>     "blockNumber" => 34,
      ...>     "index" => 0,
      ...>     "result" => %{
      ...>       "address" => "0xffc87239eb0267bc3ca2cd51d12fbf278e02ccb4",
      ...>       "code" => "0x606060405260043610610062576000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff1680630900f01014610067578063445df0ac146100a05780638da5cb5b146100c9578063fdacd5761461011e575b600080fd5b341561007257600080fd5b61009e600480803573ffffffffffffffffffffffffffffffffffffffff16906020019091905050610141565b005b34156100ab57600080fd5b6100b3610224565b6040518082815260200191505060405180910390f35b34156100d457600080fd5b6100dc61022a565b604051808273ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff16815260200191505060405180910390f35b341561012957600080fd5b61013f600480803590602001909190505061024f565b005b60008060009054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff163373ffffffffffffffffffffffffffffffffffffffff161415610220578190508073ffffffffffffffffffffffffffffffffffffffff1663fdacd5766001546040518263ffffffff167c010000000000000000000000000000000000000000000000000000000002815260040180828152602001915050600060405180830381600087803b151561020b57600080fd5b6102c65a03f1151561021c57600080fd5b5050505b5050565b60015481565b6000809054906101000a900473ffffffffffffffffffffffffffffffffffffffff1681565b6000809054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff163373ffffffffffffffffffffffffffffffffffffffff1614156102ac57806001819055505b505600a165627a7a72305820a9c628775efbfbc17477a472413c01ee9b33881f550c59d21bee9928835c854b0029",
      ...>       "gasUsed" => 166651
      ...>     },
      ...>     "subtraces" => 0,
      ...>     "traceAddress" => [],
      ...>     "transactionHash" => "0x3a3eb134e6792ce9403ea4188e5e79693de9e4c94e499db132be086400da79e6",
      ...>     "type" => "create",
      ...>     "transactionIndex" => 0
      ...>   }
      ...> )
      %{
        block_number: 34,
        created_contract_address_hash: "0xffc87239eb0267bc3ca2cd51d12fbf278e02ccb4",
        created_contract_code: "0x606060405260043610610062576000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff1680630900f01014610067578063445df0ac146100a05780638da5cb5b146100c9578063fdacd5761461011e575b600080fd5b341561007257600080fd5b61009e600480803573ffffffffffffffffffffffffffffffffffffffff16906020019091905050610141565b005b34156100ab57600080fd5b6100b3610224565b6040518082815260200191505060405180910390f35b34156100d457600080fd5b6100dc61022a565b604051808273ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff16815260200191505060405180910390f35b341561012957600080fd5b61013f600480803590602001909190505061024f565b005b60008060009054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff163373ffffffffffffffffffffffffffffffffffffffff161415610220578190508073ffffffffffffffffffffffffffffffffffffffff1663fdacd5766001546040518263ffffffff167c010000000000000000000000000000000000000000000000000000000002815260040180828152602001915050600060405180830381600087803b151561020b57600080fd5b6102c65a03f1151561021c57600080fd5b5050505b5050565b60015481565b6000809054906101000a900473ffffffffffffffffffffffffffffffffffffffff1681565b6000809054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff163373ffffffffffffffffffffffffffffffffffffffff1614156102ac57806001819055505b505600a165627a7a72305820a9c628775efbfbc17477a472413c01ee9b33881f550c59d21bee9928835c854b0029",
        from_address_hash: "0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca",
        gas: 4597044,
        gas_used: 166651,
        index: 0,
        init: "0x6060604052341561000f57600080fd5b336000806101000a81548173ffffffffffffffffffffffffffffffffffffffff021916908373ffffffffffffffffffffffffffffffffffffffff1602179055506102db8061005e6000396000f300606060405260043610610062576000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff1680630900f01014610067578063445df0ac146100a05780638da5cb5b146100c9578063fdacd5761461011e575b600080fd5b341561007257600080fd5b61009e600480803573ffffffffffffffffffffffffffffffffffffffff16906020019091905050610141565b005b34156100ab57600080fd5b6100b3610224565b6040518082815260200191505060405180910390f35b34156100d457600080fd5b6100dc61022a565b604051808273ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff16815260200191505060405180910390f35b341561012957600080fd5b61013f600480803590602001909190505061024f565b005b60008060009054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff163373ffffffffffffffffffffffffffffffffffffffff161415610220578190508073ffffffffffffffffffffffffffffffffffffffff1663fdacd5766001546040518263ffffffff167c010000000000000000000000000000000000000000000000000000000002815260040180828152602001915050600060405180830381600087803b151561020b57600080fd5b6102c65a03f1151561021c57600080fd5b5050505b5050565b60015481565b6000809054906101000a900473ffffffffffffffffffffffffffffffffffffffff1681565b6000809054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff163373ffffffffffffffffffffffffffffffffffffffff1614156102ac57806001819055505b505600a165627a7a72305820a9c628775efbfbc17477a472413c01ee9b33881f550c59d21bee9928835c854b0029",
        trace_address: [],
        transaction_hash: "0x3a3eb134e6792ce9403ea4188e5e79693de9e4c94e499db132be086400da79e6",
        type: "create",
        value: 0,
        transaction_index: 0
      }

  A create can fail due to a Bad Instruction in the `init` that is meant to form the `code` of the contract

      iex> EthereumJSONRPC.Parity.Trace.elixir_to_params(
      ...>   %{
      ...>     "action" => %{
      ...>       "from" => "0x78a42d3705fb3c26a4b54737a784bf064f0815fb",
      ...>       "gas" => 3946728,
      ...>       "init" => "0x4bb278f3",
      ...>       "value" => 0
      ...>     },
      ...>     "blockNumber" => 35,
      ...>     "error" => "Bad instruction",
      ...>     "index" => 0,
      ...>     "subtraces" => 0,
      ...>     "traceAddress" => [],
      ...>     "transactionHash" => "0x3c624bb4852fb5e35a8f45644cec7a486211f6ba89034768a2b763194f22f97d",
      ...>     "type" => "create",
      ...>     "transactionIndex" => 0
      ...>   }
      ...> )
      %{
        block_number: 35,
        error: "Bad instruction",
        from_address_hash: "0x78a42d3705fb3c26a4b54737a784bf064f0815fb",
        gas: 3946728,
        index: 0,
        init: "0x4bb278f3",
        trace_address: [],
        transaction_hash: "0x3c624bb4852fb5e35a8f45644cec7a486211f6ba89034768a2b763194f22f97d",
        type: "create",
        value: 0,
        transaction_index: 0
      }

  Call type traces are generated when a method is called.  Calls are further divided by call type.

      iex> EthereumJSONRPC.Parity.Trace.elixir_to_params(
      ...>   %{
      ...>     "action" => %{
      ...>       "callType" => "call",
      ...>       "from" => "0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca",
      ...>       "to" => "0x8bf38d4764929064f2d4d3a56520a76ab3df415b",
      ...>       "gas" => 4677320,
      ...>       "input" => "0x10855269000000000000000000000000862d67cb0773ee3f8ce7ea89b328ffea861ab3ef",
      ...>       "value" => 0
      ...>     },
      ...>     "blockNumber" => 35,
      ...>     "transactionIndex" => 0,
      ...>     "transactionHash" => "0x3a3eb134e6792ce9403ea4188e5e79693de9e4c94e499db132be086400da79e6",
      ...>     "index" => 0,
      ...>     "traceAddress" => [],
      ...>     "type" => "call",
      ...>     "result" => %{
      ...>       "gasUsed" => 27770,
      ...>       "output" => "0x"
      ...>     },
      ...>     "subtraces" => 0
      ...>   }
      ...> )
      %{
        block_number: 35,
        transaction_index: 0,
        transaction_hash: "0x3a3eb134e6792ce9403ea4188e5e79693de9e4c94e499db132be086400da79e6",
        index: 0,
        trace_address: [],
        type: "call",
        call_type: "call",
        from_address_hash: "0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca",
        to_address_hash: "0x8bf38d4764929064f2d4d3a56520a76ab3df415b",
        gas: 4677320,
        gas_used: 27770,
        input: "0x10855269000000000000000000000000862d67cb0773ee3f8ce7ea89b328ffea861ab3ef",
        output: "0x",
        value: 0
      }

  Calls can error and be reverted

     iex> EthereumJSONRPC.Parity.Trace.elixir_to_params(
     ...>   %{
     ...>     "action" => %{
     ...>       "callType" => "call",
     ...>       "from" => "0xc9266e6fdf5182dc47d27e0dc32bdff9e4cd2e32",
     ...>       "to" => "0xfdca0da4158740a93693441b35809b5bb463e527",
     ...>       "gas" => 7578728,
     ...>       "input" => "0xa6f2ae3a",
     ...>       "value" => 10000000000000000
     ...>     },
     ...>     "blockNumber" => 35,
     ...>     "transactionIndex" => 0,
     ...>     "transactionHash" => "0xcd7c15dbbc797722bef6e1d551edfd644fc7f4fb2ccd6a7947b2d1ade9ed140b",
     ...>     "index" => 0,
     ...>     "traceAddress" => [],
     ...>     "type" => "call",
     ...>     "error" => "Reverted",
     ...>     "subtraces" => 7,
     ...>   }
     ...> )
     %{
       block_number: 35,
       transaction_index: 0,
       transaction_hash: "0xcd7c15dbbc797722bef6e1d551edfd644fc7f4fb2ccd6a7947b2d1ade9ed140b",
       index: 0,
       trace_address: [],
       type: "call",
       call_type: "call",
       from_address_hash: "0xc9266e6fdf5182dc47d27e0dc32bdff9e4cd2e32",
       to_address_hash: "0xfdca0da4158740a93693441b35809b5bb463e527",
       input: "0xa6f2ae3a",
       error: "Reverted",
       gas: 7578728,
       value: 10000000000000000
     }

  Self-destruct transfer a `"balance"` from `"address"` to `"refundAddress"`.  These self-destruct-unique fields can be
  mapped to pre-existing `t:Explorer.Chain.InternalTransaction.t/0` fields.

  | Elixir            | Params               |
  |-------------------|----------------------|
  | `"address"`       | `:from_address_hash` |
  | `"balance"`       | `:value`             |
  | `"refundAddress"` | `:to_address_hash`   |

      iex> EthereumJSONRPC.Parity.Trace.elixir_to_params(
      ...>   %{
      ...>     "action" => %{
      ...>       "address" => "0xa7542d78b9a0be6147536887e0065f16182d294b",
      ...>       "balance" => 0,
      ...>       "refundAddress" => "0x59e2e9ecf133649b1a7efc731162ff09d29ca5a5"
      ...>     },
      ...>     "blockNumber" => 35,
      ...>     "index" => 1,
      ...>     "result" => nil,
      ...>     "subtraces" => 0,
      ...>     "traceAddress" => [0],
      ...>     "transactionHash" => "0xb012b8c53498c669d87d85ed90f57385848b86d3f44ed14b2784ec685d6fda98",
      ...>     "type" => "suicide",
      ...>     "transactionIndex" => 0
      ...>   }
      ...> )
      %{
        block_number: 35,
        from_address_hash: "0xa7542d78b9a0be6147536887e0065f16182d294b",
        index: 1,
        to_address_hash: "0x59e2e9ecf133649b1a7efc731162ff09d29ca5a5",
        trace_address: [0],
        transaction_hash: "0xb012b8c53498c669d87d85ed90f57385848b86d3f44ed14b2784ec685d6fda98",
        type: "selfdestruct",
        value: 0,
        transaction_index: 0
      }

  """

  def elixir_to_params(%{"type" => "call" = type} = elixir) do
    %{
      "action" => %{
        "callType" => call_type,
        "to" => to_address_hash,
        "from" => from_address_hash,
        "input" => input,
        "gas" => gas,
        "value" => value
      },
      "blockNumber" => block_number,
      "transactionIndex" => transaction_index,
      "transactionHash" => transaction_hash,
      "index" => index,
      "traceAddress" => trace_address
    } = elixir

    %{
      block_number: block_number,
      transaction_hash: transaction_hash,
      transaction_index: transaction_index,
      index: index,
      trace_address: trace_address,
      type: type,
      call_type: call_type,
      from_address_hash: from_address_hash,
      to_address_hash: to_address_hash,
      gas: gas,
      input: input,
      value: value
    }
    |> put_call_error_or_result(elixir)
  end

  def elixir_to_params(%{"type" => "create" = type} = elixir) do
    %{
      "action" => %{"from" => from_address_hash, "gas" => gas, "init" => init, "value" => value},
      "blockNumber" => block_number,
      "index" => index,
      "traceAddress" => trace_address,
      "transactionHash" => transaction_hash,
      "transactionIndex" => transaction_index
    } = elixir

    %{
      block_number: block_number,
      from_address_hash: from_address_hash,
      gas: gas,
      index: index,
      init: init,
      trace_address: trace_address,
      transaction_hash: transaction_hash,
      type: type,
      value: value,
      transaction_index: transaction_index
    }
    |> put_create_error_or_result(elixir)
  end

  def elixir_to_params(%{"type" => "suicide"} = elixir) do
    %{
      "action" => %{
        "address" => from_address_hash,
        "balance" => value,
        "refundAddress" => to_address_hash
      },
      "blockNumber" => block_number,
      "index" => index,
      "traceAddress" => trace_address,
      "transactionHash" => transaction_hash,
      "transactionIndex" => transaction_index
    } = elixir

    %{
      block_number: block_number,
      from_address_hash: from_address_hash,
      index: index,
      to_address_hash: to_address_hash,
      trace_address: trace_address,
      transaction_hash: transaction_hash,
      type: "selfdestruct",
      value: value,
      transaction_index: transaction_index
    }
  end

  @doc """
  Decodes the stringly typed numerical fields to `t:non_neg_integer/0`.

      iex> EthereumJSONRPC.Parity.Trace.to_elixir(
      ...>   %{
      ...>     "action" => %{
      ...>       "from" => "0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca",
      ...>       "gas" => "0x462534",
      ...>       "init" => "0x6060604052341561000f57600080fd5b336000806101000a81548173ffffffffffffffffffffffffffffffffffffffff021916908373ffffffffffffffffffffffffffffffffffffffff1602179055506102db8061005e6000396000f300606060405260043610610062576000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff1680630900f01014610067578063445df0ac146100a05780638da5cb5b146100c9578063fdacd5761461011e575b600080fd5b341561007257600080fd5b61009e600480803573ffffffffffffffffffffffffffffffffffffffff16906020019091905050610141565b005b34156100ab57600080fd5b6100b3610224565b6040518082815260200191505060405180910390f35b34156100d457600080fd5b6100dc61022a565b604051808273ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff16815260200191505060405180910390f35b341561012957600080fd5b61013f600480803590602001909190505061024f565b005b60008060009054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff163373ffffffffffffffffffffffffffffffffffffffff161415610220578190508073ffffffffffffffffffffffffffffffffffffffff1663fdacd5766001546040518263ffffffff167c010000000000000000000000000000000000000000000000000000000002815260040180828152602001915050600060405180830381600087803b151561020b57600080fd5b6102c65a03f1151561021c57600080fd5b5050505b5050565b60015481565b6000809054906101000a900473ffffffffffffffffffffffffffffffffffffffff1681565b6000809054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff163373ffffffffffffffffffffffffffffffffffffffff1614156102ac57806001819055505b505600a165627a7a72305820a9c628775efbfbc17477a472413c01ee9b33881f550c59d21bee9928835c854b0029",
      ...>       "value" => "0x0"
      ...>     },
      ...>     "blockNumber" => 1,
      ...>     "index" => 0,
      ...>     "result" => %{
      ...>       "address" => "0xffc87239eb0267bc3ca2cd51d12fbf278e02ccb4",
      ...>       "code" => "0x606060405260043610610062576000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff1680630900f01014610067578063445df0ac146100a05780638da5cb5b146100c9578063fdacd5761461011e575b600080fd5b341561007257600080fd5b61009e600480803573ffffffffffffffffffffffffffffffffffffffff16906020019091905050610141565b005b34156100ab57600080fd5b6100b3610224565b6040518082815260200191505060405180910390f35b34156100d457600080fd5b6100dc61022a565b604051808273ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff16815260200191505060405180910390f35b341561012957600080fd5b61013f600480803590602001909190505061024f565b005b60008060009054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff163373ffffffffffffffffffffffffffffffffffffffff161415610220578190508073ffffffffffffffffffffffffffffffffffffffff1663fdacd5766001546040518263ffffffff167c010000000000000000000000000000000000000000000000000000000002815260040180828152602001915050600060405180830381600087803b151561020b57600080fd5b6102c65a03f1151561021c57600080fd5b5050505b5050565b60015481565b6000809054906101000a900473ffffffffffffffffffffffffffffffffffffffff1681565b6000809054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff163373ffffffffffffffffffffffffffffffffffffffff1614156102ac57806001819055505b505600a165627a7a72305820a9c628775efbfbc17477a472413c01ee9b33881f550c59d21bee9928835c854b0029",
      ...>       "gasUsed" => "0x28afb"
      ...>     },
      ...>     "subtraces" => 0,
      ...>     "traceAddress" => [],
      ...>     "transactionHash" => "0x3a3eb134e6792ce9403ea4188e5e79693de9e4c94e499db132be086400da79e6",
      ...>     "transactionIndex" => 0,
      ...>     "type" => "create"
      ...>   }
      ...> )
      %{
        "action" => %{
          "from" => "0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca",
          "gas" => 4597044,
          "init" => "0x6060604052341561000f57600080fd5b336000806101000a81548173ffffffffffffffffffffffffffffffffffffffff021916908373ffffffffffffffffffffffffffffffffffffffff1602179055506102db8061005e6000396000f300606060405260043610610062576000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff1680630900f01014610067578063445df0ac146100a05780638da5cb5b146100c9578063fdacd5761461011e575b600080fd5b341561007257600080fd5b61009e600480803573ffffffffffffffffffffffffffffffffffffffff16906020019091905050610141565b005b34156100ab57600080fd5b6100b3610224565b6040518082815260200191505060405180910390f35b34156100d457600080fd5b6100dc61022a565b604051808273ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff16815260200191505060405180910390f35b341561012957600080fd5b61013f600480803590602001909190505061024f565b005b60008060009054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff163373ffffffffffffffffffffffffffffffffffffffff161415610220578190508073ffffffffffffffffffffffffffffffffffffffff1663fdacd5766001546040518263ffffffff167c010000000000000000000000000000000000000000000000000000000002815260040180828152602001915050600060405180830381600087803b151561020b57600080fd5b6102c65a03f1151561021c57600080fd5b5050505b5050565b60015481565b6000809054906101000a900473ffffffffffffffffffffffffffffffffffffffff1681565b6000809054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff163373ffffffffffffffffffffffffffffffffffffffff1614156102ac57806001819055505b505600a165627a7a72305820a9c628775efbfbc17477a472413c01ee9b33881f550c59d21bee9928835c854b0029",
          "value" => 0
        },
        "blockNumber" => 1,
        "index" => 0,
        "result" => %{
          "address" => "0xffc87239eb0267bc3ca2cd51d12fbf278e02ccb4",
          "code" => "0x606060405260043610610062576000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff1680630900f01014610067578063445df0ac146100a05780638da5cb5b146100c9578063fdacd5761461011e575b600080fd5b341561007257600080fd5b61009e600480803573ffffffffffffffffffffffffffffffffffffffff16906020019091905050610141565b005b34156100ab57600080fd5b6100b3610224565b6040518082815260200191505060405180910390f35b34156100d457600080fd5b6100dc61022a565b604051808273ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff16815260200191505060405180910390f35b341561012957600080fd5b61013f600480803590602001909190505061024f565b005b60008060009054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff163373ffffffffffffffffffffffffffffffffffffffff161415610220578190508073ffffffffffffffffffffffffffffffffffffffff1663fdacd5766001546040518263ffffffff167c010000000000000000000000000000000000000000000000000000000002815260040180828152602001915050600060405180830381600087803b151561020b57600080fd5b6102c65a03f1151561021c57600080fd5b5050505b5050565b60015481565b6000809054906101000a900473ffffffffffffffffffffffffffffffffffffffff1681565b6000809054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff163373ffffffffffffffffffffffffffffffffffffffff1614156102ac57806001819055505b505600a165627a7a72305820a9c628775efbfbc17477a472413c01ee9b33881f550c59d21bee9928835c854b0029",
          "gasUsed" => 166651
        },
        "subtraces" => 0,
        "traceAddress" => [],
        "transactionHash" => "0x3a3eb134e6792ce9403ea4188e5e79693de9e4c94e499db132be086400da79e6",
        "transactionIndex" => 0,
        "type" => "create"
      }

  The caller must put `"blockNumber"`, `"index"`, and `"transactionHash"` into the incoming map, as Parity itself does
  not include that information, but it is needed to locate the trace in history and update addresses fully.

      iex> EthereumJSONRPC.Parity.Trace.to_elixir(
      ...>   %{
      ...>     "action" => %{
      ...>       "from" => "0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca",
      ...>       "gas" => "0x462534",
      ...>       "init" => "0x6060604052341561000f57600080fd5b336000806101000a81548173ffffffffffffffffffffffffffffffffffffffff021916908373ffffffffffffffffffffffffffffffffffffffff1602179055506102db8061005e6000396000f300606060405260043610610062576000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff1680630900f01014610067578063445df0ac146100a05780638da5cb5b146100c9578063fdacd5761461011e575b600080fd5b341561007257600080fd5b61009e600480803573ffffffffffffffffffffffffffffffffffffffff16906020019091905050610141565b005b34156100ab57600080fd5b6100b3610224565b6040518082815260200191505060405180910390f35b34156100d457600080fd5b6100dc61022a565b604051808273ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff16815260200191505060405180910390f35b341561012957600080fd5b61013f600480803590602001909190505061024f565b005b60008060009054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff163373ffffffffffffffffffffffffffffffffffffffff161415610220578190508073ffffffffffffffffffffffffffffffffffffffff1663fdacd5766001546040518263ffffffff167c010000000000000000000000000000000000000000000000000000000002815260040180828152602001915050600060405180830381600087803b151561020b57600080fd5b6102c65a03f1151561021c57600080fd5b5050505b5050565b60015481565b6000809054906101000a900473ffffffffffffffffffffffffffffffffffffffff1681565b6000809054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff163373ffffffffffffffffffffffffffffffffffffffff1614156102ac57806001819055505b505600a165627a7a72305820a9c628775efbfbc17477a472413c01ee9b33881f550c59d21bee9928835c854b0029",
      ...>       "value" => "0x0"
      ...>     },
      ...>     "result" => %{
      ...>       "address" => "0xffc87239eb0267bc3ca2cd51d12fbf278e02ccb4",
      ...>       "code" => "0x606060405260043610610062576000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff1680630900f01014610067578063445df0ac146100a05780638da5cb5b146100c9578063fdacd5761461011e575b600080fd5b341561007257600080fd5b61009e600480803573ffffffffffffffffffffffffffffffffffffffff16906020019091905050610141565b005b34156100ab57600080fd5b6100b3610224565b6040518082815260200191505060405180910390f35b34156100d457600080fd5b6100dc61022a565b604051808273ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff16815260200191505060405180910390f35b341561012957600080fd5b61013f600480803590602001909190505061024f565b005b60008060009054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff163373ffffffffffffffffffffffffffffffffffffffff161415610220578190508073ffffffffffffffffffffffffffffffffffffffff1663fdacd5766001546040518263ffffffff167c010000000000000000000000000000000000000000000000000000000002815260040180828152602001915050600060405180830381600087803b151561020b57600080fd5b6102c65a03f1151561021c57600080fd5b5050505b5050565b60015481565b6000809054906101000a900473ffffffffffffffffffffffffffffffffffffffff1681565b6000809054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff163373ffffffffffffffffffffffffffffffffffffffff1614156102ac57806001819055505b505600a165627a7a72305820a9c628775efbfbc17477a472413c01ee9b33881f550c59d21bee9928835c854b0029",
      ...>       "gasUsed" => "0x28afb"
      ...>     },
      ...>     "subtraces" => 0,
      ...>     "traceAddress" => [],
      ...>     "transactionIndex" => 0,
      ...>     "type" => "create"
      ...>   }
      ...> )
      ** (ArgumentError) Caller must `Map.put/2` `"blockNumber"`, `"index"`, `"transactionHash"` and `"transactionIndex"` in trace

  `"suicide"` `"type"` traces are different in that they have a `nil` `"result"`.  This is because the `"result"` key
  is used to indicate success from Parity.

      iex> EthereumJSONRPC.Parity.Trace.to_elixir(
      ...>   %{
      ...>     "action" => %{
      ...>       "address" => "0xa7542d78b9a0be6147536887e0065f16182d294b",
      ...>       "balance" => "0x0",
      ...>       "refundAddress" => "0x59e2e9ecf133649b1a7efc731162ff09d29ca5a5"
      ...>     },
      ...>     "blockNumber" => 1,
      ...>     "index" => 1,
      ...>     "result" => nil,
      ...>     "subtraces" => 0,
      ...>     "traceAddress" => [0],
      ...>     "transactionHash" => "0xb012b8c53498c669d87d85ed90f57385848b86d3f44ed14b2784ec685d6fda98",
      ...>     "transactionIndex" => 0,
      ...>     "type" => "suicide"
      ...>   }
      ...> )
      %{
        "action" => %{
          "address" => "0xa7542d78b9a0be6147536887e0065f16182d294b",
          "balance" => 0,
          "refundAddress" => "0x59e2e9ecf133649b1a7efc731162ff09d29ca5a5"
        },
        "blockNumber" => 1,
        "index" => 1,
        "result" => nil,
        "subtraces" => 0,
        "traceAddress" => [0],
        "transactionHash" => "0xb012b8c53498c669d87d85ed90f57385848b86d3f44ed14b2784ec685d6fda98",
        "transactionIndex" => 0,
        "type" => "suicide"
      }

  A call type trace can error and be reverted.

      iex> EthereumJSONRPC.Parity.Trace.to_elixir(
      ...>   %{
      ...>     "action" => %{
      ...>       "callType" => "call",
      ...>       "from" => "0xc9266e6fdf5182dc47d27e0dc32bdff9e4cd2e32",
      ...>       "gas" => "0x73a468",
      ...>       "input" => "0xa6f2ae3a",
      ...>       "to" => "0xfdca0da4158740a93693441b35809b5bb463e527",
      ...>       "value" => "0x2386f26fc10000"
      ...>     },
      ...>     "blockNumber" => 1,
      ...>     "blockHash" => "0x940ec4bab528861b5c5904c8d143d466a2b237e4b8c9bc96201dfde037d185f2",
      ...>     "error" => "Reverted",
      ...>     "index" => 0,
      ...>     "subtraces" => 7,
      ...>     "traceAddress" => [],
      ...>     "transactionHash" => "0xcd7c15dbbc797722bef6e1d551edfd644fc7f4fb2ccd6a7947b2d1ade9ed140b",
      ...>     "transactionIndex" => 0,
      ...>     "type" => "call"
      ...>   }
      ...> )
      %{
        "action" => %{
          "callType" => "call",
          "from" => "0xc9266e6fdf5182dc47d27e0dc32bdff9e4cd2e32",
          "gas" => 7578728,
          "input" => "0xa6f2ae3a",
          "to" => "0xfdca0da4158740a93693441b35809b5bb463e527",
          "value" => 10000000000000000
        },
        "blockNumber" => 1,
        "blockHash" => "0x940ec4bab528861b5c5904c8d143d466a2b237e4b8c9bc96201dfde037d185f2",
        "error" => "Reverted",
        "index" => 0,
        "subtraces" => 7,
        "traceAddress" => [],
        "transactionHash" => "0xcd7c15dbbc797722bef6e1d551edfd644fc7f4fb2ccd6a7947b2d1ade9ed140b",
        "transactionIndex" => 0,
        "type" => "call"
      }

  """

  def to_elixir(%{"blockNumber" => _, "index" => _, "transactionHash" => _, "transactionIndex" => _} = trace)
      when is_map(trace) do
    Enum.into(trace, %{}, &entry_to_elixir/1)
  end

  def to_elixir(_) do
    raise ArgumentError,
          ~S|Caller must `Map.put/2` `"blockNumber"`, `"index"`, `"transactionHash"` and `"transactionIndex"` in trace|
  end

  # subtraces is an actual integer in JSON and not hex-encoded
  # traceAddress is a list of actual integers, not a list of hex-encoded
  defp entry_to_elixir({key, _} = entry)
       when key in ~w(subtraces traceAddress transactionHash blockHash type output),
       do: entry

  defp entry_to_elixir({"action" = key, action}) do
    {key, Action.to_elixir(action)}
  end

  defp entry_to_elixir({"blockNumber", block_number} = entry) when is_integer(block_number),
    do: entry

  defp entry_to_elixir({"error", reason} = entry) when is_binary(reason), do: entry

  defp entry_to_elixir({"index", index} = entry) when is_integer(index), do: entry

  defp entry_to_elixir({"revertReason", reason} = entry) when is_binary(reason), do: entry
  
  defp entry_to_elixir({"result" = key, result}) do
    {key, Result.to_elixir(result)}
  end

  defp entry_to_elixir({"transactionIndex", index} = entry) when is_integer(index), do: entry

  defp put_call_error_or_result(params, %{
         "result" => %{"gasUsed" => gas_used, "output" => output}
       }) do
    Map.merge(params, %{gas_used: gas_used, output: output})
  end

  defp put_call_error_or_result(params, %{"error" => error}) do
    Map.put(params, :error, error)
  end

  defp put_create_error_or_result(params, %{
         "result" => %{
           "address" => created_contract_address_hash,
           "code" => code,
           "gasUsed" => gas_used
         }
       }) do
    Map.merge(params, %{
      created_contract_code: code,
      created_contract_address_hash: created_contract_address_hash,
      gas_used: gas_used
    })
  end

  defp put_create_error_or_result(params, %{"error" => error}) do
    Map.put(params, :error, error)
  end
end
