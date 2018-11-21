defmodule EthereumJSONRPC.Geth.Calls do
  @moduledoc """
  Calls returned from [debug_traceTransaction](https://github.com/ethereum/go-ethereum/wiki/Management-APIs#debug_tracetransaction)
  using a custom tracer (`priv/js/ethereum_jsonrpc/geth/debug_traceTransaction/tracer.js`).
  """

  alias EthereumJSONRPC.Geth.Call

  @doc """
  Converts a sequence of calls to internal transaction params.

  A sequence of calls:

      iex> EthereumJSONRPC.Geth.Calls.to_internal_transactions_params(
      ...>   [
      ...>     %{
      ...>       "blockNumber" => 3287375,
      ...>       "transactionIndex" => 13,
      ...>       "transactionHash" => "0x32b17f27ddb546eab3c4c33f31eb22c1cb992d4ccc50dae26922805b717efe5c",
      ...>       "index" => 0,
      ...>       "traceAddress" => [],
      ...>       "type" => "call",
      ...>       "callType" => "call",
      ...>       "from" => "0xa931c862e662134b85e4dc4baf5c70cc9ba74db4",
      ...>       "to" => "0x1469b17ebf82fedf56f04109e5207bdc4554288c",
      ...>       "gas" => "0x8600",
      ...>       "gasUsed" => "0x7d37",
      ...>       "input" => "0xb118e2db0000000000000000000000000000000000000000000000000000000000000008",
      ...>       "output" => "0x",
      ...>       "value" => "0x174876e800"
      ...>     },
      ...>     %{
      ...>       "blockNumber" => 3287375,
      ...>       "transactionIndex" => 13,
      ...>       "transactionHash" => "0x32b17f27ddb546eab3c4c33f31eb22c1cb992d4ccc50dae26922805b717efe5c",
      ...>       "index" => 1,
      ...>       "traceAddress" => [0],
      ...>       "type" => "call",
      ...>       "callType" => "call",
      ...>       "from" => "0x1469b17ebf82fedf56f04109e5207bdc4554288c",
      ...>       "to" => "0xf8d67a2d17b7936bda99585d921fd7276fc5cac7",
      ...>       "gas" => "0x25e4",
      ...>       "gasUsed" => "0x1ce8",
      ...>       "input" => "0x",
      ...>       "output" => "0x",
      ...>       "value" => "0x174876e800"
      ...>     }
      ...>   ]
      ...> )
      [
        %{
          block_number: 3287375,
          transaction_index: 13,
          transaction_hash: "0x32b17f27ddb546eab3c4c33f31eb22c1cb992d4ccc50dae26922805b717efe5c",
          index: 0,
          trace_address: [],
          type: "call",
          call_type: "call",
          from_address_hash: "0xa931c862e662134b85e4dc4baf5c70cc9ba74db4",
          to_address_hash: "0x1469b17ebf82fedf56f04109e5207bdc4554288c",
          gas: 34304,
          gas_used: 32055,
          input: "0xb118e2db0000000000000000000000000000000000000000000000000000000000000008",
          output: "0x",
          value: 100000000000
        },
        %{
          block_number: 3287375,
          transaction_index: 13,
          transaction_hash: "0x32b17f27ddb546eab3c4c33f31eb22c1cb992d4ccc50dae26922805b717efe5c",
          index: 1,
          trace_address: [0],
          type: "call",
          call_type: "call",
          from_address_hash: "0x1469b17ebf82fedf56f04109e5207bdc4554288c",
          to_address_hash: "0xf8d67a2d17b7936bda99585d921fd7276fc5cac7",
          gas: 9700,
          gas_used: 7400,
          input: "0x",
          output: "0x",
          value: 100000000000
        }
      ]

  A call can run out of gas:

      iex> EthereumJSONRPC.Geth.Calls.to_internal_transactions_params(
      ...>   [
      ...>     %{
      ...>       "blockNumber" => 3293221,
      ...>       "transactionIndex" => 16,
      ...>       "transactionHash" => "0xa9a893fe2f019831496cec9777ad25ff940823b9b47a3969299ea139e42b2073",
      ...>       "index" => 0,
      ...>       "traceAddress" => [],
      ...>       "type" => "call",
      ...>       "callType" => "call",
      ...>       "from" => "0x8ec75ef3adf6c953775d0738e0e7bd60e647e5ef",
      ...>       "to" => "0xaae465ad04b12e90c32291e59b65ca781c57e361",
      ...>       "gas" => "0x4c9",
      ...>       "gasUsed" => "0x4c9",
      ...>       "input" => "0xa83627de",
      ...>       "error" => "out of gas",
      ...>       "value" => "0x0"
      ...>     }
      ...>   ]
      ...> )
      [
        %{
          block_number: 3293221,
          transaction_index: 16,
          transaction_hash: "0xa9a893fe2f019831496cec9777ad25ff940823b9b47a3969299ea139e42b2073",
          index: 0,
          trace_address: [],
          type: "call",
          call_type: "call",
          input: "0xa83627de",
          error: "out of gas",
          from_address_hash: "0x8ec75ef3adf6c953775d0738e0e7bd60e647e5ef",
          to_address_hash: "0xaae465ad04b12e90c32291e59b65ca781c57e361",
          gas: 1225,
          value: 0
        }
      ]

  A contract creation:

      iex> EthereumJSONRPC.Geth.Calls.to_internal_transactions_params(
      ...>   [
      ...>     %{
      ...>       "blockNumber" => 3292697,
      ...>       "transactionIndex" => 1,
      ...>       "transactionHash" => "0x248a832af263a298b9869ee9a669c2c86a3676799b0b8b566c6dd452daaedbf6",
      ...>       "index" => 0,
      ...>       "traceAddress" => [],
      ...>       "type" => "create",
      ...>       "from" => "0xb95754d27da16a0f17aba278fc10a69e1c9fee1c",
      ...>       "createdContractAddressHash" => "0x08d24f568715041e72223cc023e806060de8a2a5",
      ...>       "gas" => "0x5e46ef",
      ...>       "gasUsed" => "0x168a8a",
      ...>       "init" => "0x",
      ...>       "createdContractCode" => "0x",
      ...>       "value" => "0x0"
      ...>     }
      ...>   ]
      ...> )
      [
        %{
          block_number: 3292697,
          transaction_index: 1,
          transaction_hash: "0x248a832af263a298b9869ee9a669c2c86a3676799b0b8b566c6dd452daaedbf6",
          index: 0,
          trace_address: [],
          type: "create",
          from_address_hash: "0xb95754d27da16a0f17aba278fc10a69e1c9fee1c",
          created_contract_address_hash: "0x08d24f568715041e72223cc023e806060de8a2a5",
          gas: 6178543,
          gas_used: 1477258,
          init: "0x",
          created_contract_code: "0x",
          value: 0
        }
      ]

  Contract creation can happen indirectly through a call:

      iex> EthereumJSONRPC.Geth.Calls.to_internal_transactions_params(
      ...>   [
      ...>     %{
      ...>       "blockNumber" => 3293393,
      ...>       "transactionIndex" => 13,
      ...>       "transactionHash" => "0x19379505cd9fcd16f19d92f23dc323ee921991da1f169df2af1d93fdb8bca461",
      ...>       "index" => 0,
      ...>       "traceAddress" => [],
      ...>       "type" => "call",
      ...>       "callType" => "call",
      ...>       "from" => "0x129f447137b03ee3d8bbad62ef5d89021d944324",
      ...>       "to" => "0x2c8a58ddba2dc097ea0f95db6cd51ac7d31d1518",
      ...>       "gas" => "0x18d2c2",
      ...>       "gasUsed" => "0x106e24",
      ...>       "input" => "0xe9696f54",
      ...>       "output" => "0x0000000000000000000000009b5a1dcfd53caa108ef83cf2ff0e17db27facf0f",
      ...>       "value" => "0x0"
      ...>     },
      ...>     %{
      ...>       "blockNumber" => 3293393,
      ...>       "transactionIndex" => 13,
      ...>       "transactionHash" => "0x19379505cd9fcd16f19d92f23dc323ee921991da1f169df2af1d93fdb8bca461",
      ...>       "index" => 1,
      ...>       "traceAddress" => [0],
      ...>       "type" => "create",
      ...>       "from" => "0x2c8a58ddba2dc097ea0f95db6cd51ac7d31d1518",
      ...>       "createdContractAddressHash" => "0x9b5a1dcfd53caa108ef83cf2ff0e17db27facf0f",
      ...>       "gas" => "0x18c869",
      ...>       "gasUsed" => "0xfe428",
      ...>       "init" => "0x6080604",
      ...>       "createdContractCode" => "0x608060",
      ...>       "value" => "0x0"
      ...>     }
      ...>   ]
      ...> )
      [
        %{
          block_number: 3293393,
          transaction_index: 13,
          transaction_hash: "0x19379505cd9fcd16f19d92f23dc323ee921991da1f169df2af1d93fdb8bca461",
          index: 0,
          trace_address: [],
          type: "call",
          call_type: "call",
          from_address_hash: "0x129f447137b03ee3d8bbad62ef5d89021d944324",
          to_address_hash: "0x2c8a58ddba2dc097ea0f95db6cd51ac7d31d1518",
          gas: 1626818,
          gas_used: 1076772,
          input: "0xe9696f54",
          output: "0x0000000000000000000000009b5a1dcfd53caa108ef83cf2ff0e17db27facf0f",
          value: 0
        },
        %{
          block_number: 3293393,
          transaction_index: 13,
          trace_address: [0],
          transaction_hash: "0x19379505cd9fcd16f19d92f23dc323ee921991da1f169df2af1d93fdb8bca461",
          index: 1,
          type: "create",
          created_contract_address_hash: "0x9b5a1dcfd53caa108ef83cf2ff0e17db27facf0f",
          from_address_hash: "0x2c8a58ddba2dc097ea0f95db6cd51ac7d31d1518",
          gas: 1624169,
          gas_used: 1041448,
          init: "0x6080604",
          created_contract_code: "0x608060",
          value: 0
        }
      ]

  """
  def to_internal_transactions_params(calls) when is_list(calls) do
    Enum.map(calls, &Call.to_internal_transaction_params/1)
  end
end
