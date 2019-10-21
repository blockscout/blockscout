defmodule EthereumJSONRPC.Geth.Call do
  @moduledoc """
  A single call returned from [debug_traceTransaction](https://github.com/ethereum/go-ethereum/wiki/Management-APIs#debug_tracetransaction)
  using a custom tracer (`priv/js/ethereum_jsonrpc/geth/debug_traceTransaction/tracer.js`).
  """
  import EthereumJSONRPC, only: [quantity_to_integer: 1]

  @doc """
  A call can call another another contract:

      iex> EthereumJSONRPC.Geth.Call.to_internal_transaction_params(
      ...>   %{
      ...>     "blockNumber" => 3287375,
      ...>     "transactionIndex" => 13,
      ...>     "transactionHash" => "0x32b17f27ddb546eab3c4c33f31eb22c1cb992d4ccc50dae26922805b717efe5c",
      ...>     "index" => 0,
      ...>     "traceAddress" => [],
      ...>     "type" => "call",
      ...>     "callType" => "call",
      ...>     "from" => "0xa931c862e662134b85e4dc4baf5c70cc9ba74db4",
      ...>     "to" => "0x1469b17ebf82fedf56f04109e5207bdc4554288c",
      ...>     "gas" => "0x8600",
      ...>     "gasUsed" => "0x7d37",
      ...>     "input" => "0xb118e2db0000000000000000000000000000000000000000000000000000000000000008",
      ...>     "output" => "0x",
      ...>     "value" => "0x174876e800"
      ...>   }
      ...> )
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
      }

  A call can run out of gas:

      iex> EthereumJSONRPC.Geth.Call.to_internal_transaction_params(
      ...>   %{
      ...>     "blockNumber" => 3293221,
      ...>     "transactionIndex" => 16,
      ...>     "transactionHash" => "0xa9a893fe2f019831496cec9777ad25ff940823b9b47a3969299ea139e42b2073",
      ...>     "index" => 0,
      ...>     "traceAddress" => [],
      ...>     "type" => "call",
      ...>     "callType" => "call",
      ...>     "from" => "0x8ec75ef3adf6c953775d0738e0e7bd60e647e5ef",
      ...>     "to" => "0xaae465ad04b12e90c32291e59b65ca781c57e361",
      ...>     "input" => "0xa83627de",
      ...>     "error" => "out of gas",
      ...>     "gas" => "0x4c9",
      ...>     "gasUsed" => "0x4c9",
      ...>     "value" => "0x0"
      ...>   }
      ...> )
      %{
        block_number: 3293221,
        transaction_index: 16,
        transaction_hash: "0xa9a893fe2f019831496cec9777ad25ff940823b9b47a3969299ea139e42b2073",
        index: 0,
        trace_address: [],
        type: "call",
        call_type: "call",
        error: "out of gas",
        from_address_hash: "0x8ec75ef3adf6c953775d0738e0e7bd60e647e5ef",
        to_address_hash: "0xaae465ad04b12e90c32291e59b65ca781c57e361",
        gas: 1225,
        input: "0xa83627de",
        value: 0
      }

  A call can reach the stack limit (1024):

      iex> EthereumJSONRPC.Geth.Call.to_internal_transaction_params(
      ...>   %{
      ...>     "blockNumber" => 3293621,
      ...>     "transactionIndex" => 7,
      ...>     "transactionHash" => "0xc4f4ba28bf8e6093b3f5932191a7a6af1dd17517c2b0e1be3b76dc445564a9ff",
      ...>     "index" => 64,
      ...>     "traceAddress" => [],
      ...>     "type" => "call",
      ...>     "callType" => "call",
      ...>     "from" => "0xaf7cf620c3df1b9ccbc640be903d5ea6cea7bc96",
      ...>     "to" => "0x80629758f88b3f30b7f1244e4588444d6276eef0",
      ...>     "input" => "0x49b46d5d",
      ...>     "error" => "stack limit reached 1024 (1024)",
      ...>     "gas" => "0x160ecc",
      ...>     "gasUsed" => "0x160ecc",
      ...>     "value" => "0x0"
      ...>   }
      ...> )
      %{
        block_number: 3293621,
        transaction_index: 7,
        transaction_hash: "0xc4f4ba28bf8e6093b3f5932191a7a6af1dd17517c2b0e1be3b76dc445564a9ff",
        index: 64,
        trace_address: [],
        type: "call",
        call_type: "call",
        from_address_hash: "0xaf7cf620c3df1b9ccbc640be903d5ea6cea7bc96",
        to_address_hash: "0x80629758f88b3f30b7f1244e4588444d6276eef0",
        input: "0x49b46d5d",
        error: "stack limit reached 1024 (1024)",
        gas: 1445580,
        value: 0
      }

  A contract creation:

      iex> EthereumJSONRPC.Geth.Call.to_internal_transaction_params(
      ...>   %{
      ...>     "blockNumber" => 3292697,
      ...>     "transactionIndex" => 1,
      ...>     "transactionHash" => "0x248a832af263a298b9869ee9a669c2c86a3676799b0b8b566c6dd452daaedbf6",
      ...>     "index" => 0,
      ...>     "traceAddress" => [],
      ...>     "type" => "create",
      ...>     "from" => "0xb95754d27da16a0f17aba278fc10a69e1c9fee1c",
      ...>     "createdContractAddressHash" => "0x08d24f568715041e72223cc023e806060de8a2a5",
      ...>     "gas" => "0x5e46ef",
      ...>     "gasUsed" => "0x168a8a",
      ...>     "init" => "0x",
      ...>     "createdContractCode" => "0x",
      ...>     "value" => "0x0"
      ...>   }
      ...> )
      %{
        block_number: 3292697,
        transaction_index: 1,
        transaction_hash: "0x248a832af263a298b9869ee9a669c2c86a3676799b0b8b566c6dd452daaedbf6",
        index: 0,
        type: "create",
        from_address_hash: "0xb95754d27da16a0f17aba278fc10a69e1c9fee1c",
        created_contract_address_hash: "0x08d24f568715041e72223cc023e806060de8a2a5",
        gas: 6178543,
        gas_used: 1477258,
        init: "0x",
        created_contract_code: "0x",
        trace_address: [],
        value: 0
      }

  A contract creation can fail:

      iex> EthereumJSONRPC.Geth.Call.to_internal_transaction_params(
      ...>   %{
      ...>     "blockNumber" => 3299287,
      ...>     "transactionIndex" => 14,
      ...>     "transactionHash" => "0x5c0c728190e593f2bbcbd9d7f851cbfbcaf041e41ce1b1eead97c301deb071fa",
      ...>     "index" => 0,
      ...>     "traceAddress" => [],
      ...>     "type" => "create",
      ...>     "from" => "0x0a49007c56c5f9eda04a2ae4229da03a30be892e",
      ...>     "gas" => "0x84068",
      ...>     "gasUsed" => "0x84068",
      ...>     "init" => "0xf49e4745",
      ...>     "error" => "stack underflow (0 <=> 6)",
      ...>     "value" => "0x12c94dd59ce493"
      ...>   }
      ...> )
      %{
        block_number: 3299287,
        transaction_index: 14,
        transaction_hash: "0x5c0c728190e593f2bbcbd9d7f851cbfbcaf041e41ce1b1eead97c301deb071fa",
        index: 0,
        trace_address: [],
        type: "create",
        from_address_hash: "0x0a49007c56c5f9eda04a2ae4229da03a30be892e",
        init: "0xf49e4745",
        error: "stack underflow (0 <=> 6)",
        gas: 540776,
        value: 5287885714285715
      }

  A delegate call uses the current contract's state, but the called contract's code:

      iex> EthereumJSONRPC.Geth.Call.to_internal_transaction_params(
      ...> %{
      ...>     "blockNumber" => 3292842,
      ...>     "transactionIndex" => 21,
      ...>     "transactionHash" => "0x6cf0aa434f6500251ce8579d031c821b9fd4b687685b21c368f1c1106e9a49a9",
      ...>     "index" => 1,
      ...>     "traceAddress" => [0],
      ...>     "type" => "call",
      ...>     "callType" => "delegatecall",
      ...>     "from" => "0x54a298ee9fccbf0ad8e55bc641d3086b81a48c41",
      ...>     "to" => "0x147e7f491ddabc0488edb47f8700633dbaad1fd1",
      ...>     "gas" => "0x40289",
      ...>     "gasUsed" => "0x17df",
      ...>     "input" => "0xeb9d50e46930b3227102b442f93b4aed3dead4ed76f850a76ee7f8b2cbe763428f2790530000000000000000000000000000000000000000000000000926708dfd7272e3",
      ...>     "output" => "0x",
      ...>     "value" => "0x0"
      ...>   }
      ...> )
      %{
        block_number: 3292842,
        transaction_index: 21,
        transaction_hash: "0x6cf0aa434f6500251ce8579d031c821b9fd4b687685b21c368f1c1106e9a49a9",
        index: 1,
        trace_address: [0],
        type: "call",
        call_type: "delegatecall",
        from_address_hash: "0x54a298ee9fccbf0ad8e55bc641d3086b81a48c41",
        to_address_hash: "0x147e7f491ddabc0488edb47f8700633dbaad1fd1",
        gas: 262793,
        gas_used: 6111,
        input: "0xeb9d50e46930b3227102b442f93b4aed3dead4ed76f850a76ee7f8b2cbe763428f2790530000000000000000000000000000000000000000000000000926708dfd7272e3",
        output: "0x",
        value: 0
      }

  A static call calls another contract, but no state can change.  This includes no value transfer, so the value for the
  call is always `0`.  If the called contract does attempt a state change, the call will error.

      iex> EthereumJSONRPC.Geth.Call.to_internal_transaction_params(
      ...>   %{
      ...>     "blockNumber" => 3293660,
      ...>     "transactionIndex" => 0,
      ...>     "transactionHash" => "0xb49ac6385dce60e2d88d8b4579f4e70a23cd40b45ecb29eb6c6069efc895325b",
      ...>     "index" => 1,
      ...>     "traceAddress" => [0],
      ...>     "type" => "call",
      ...>     "callType" => "staticcall",
      ...>     "from" => "0xa4b3886db53bebdabbe17592a57886810b906200",
      ...>     "to" => "0x20f47d830b01c4f4af4b7663a8143d230fcdc0c8",
      ...>     "input" => "0x0f370699",
      ...>     "output" => "0x",
      ...>     "gas" => "0x478d26",
      ...>     "gasUsed" => "0x410",
      ...>     "value" => "0x0"
      ...>   }
      ...> )
      %{
        block_number: 3293660,
        transaction_index: 0,
        transaction_hash: "0xb49ac6385dce60e2d88d8b4579f4e70a23cd40b45ecb29eb6c6069efc895325b",
        index: 1,
        trace_address: [0],
        type: "call",
        call_type: "staticcall",
        from_address_hash: "0xa4b3886db53bebdabbe17592a57886810b906200",
        to_address_hash: "0x20f47d830b01c4f4af4b7663a8143d230fcdc0c8",
        gas: 4689190,
        gas_used: 1040,
        input: "0x0f370699",
        output: "0x",
        value: 0
      }

  A selfdestruct destroys the calling contract and sends any left over balance to the to address.

      iex> EthereumJSONRPC.Geth.Call.to_internal_transaction_params(
      ...>   %{
      ...>     "blockNumber" => 3298074,
      ...>     "transactionIndex" => 9,
      ...>     "transactionHash" => "0xe098557c8fa82be6779f5c2b3f248e990e2dc67b6bd60a4fa4a9aa66f6c24c08",
      ...>     "index" => 32,
      ...>     "traceAddress" => [1],
      ...>     "type" => "selfdestruct",
      ...>     "from" => "0x9317da7be8e05f36f329a95f004a44552effb968",
      ...>     "to" => "0xff77830c100623316736b45c4983df970423aaf4",
      ...>     "gas" => "0xb52c8",
      ...>     "gasUsed" => "0xaf6b5",
      ...>     "value" => "0x0"
      ...>   }
      ...> )
      %{
        block_number: 3298074,
        transaction_index: 9,
        transaction_hash: "0xe098557c8fa82be6779f5c2b3f248e990e2dc67b6bd60a4fa4a9aa66f6c24c08",
        index: 32,
        trace_address: [1],
        type: "selfdestruct",
        from_address_hash: "0x9317da7be8e05f36f329a95f004a44552effb968",
        to_address_hash: "0xff77830c100623316736b45c4983df970423aaf4",
        gas: 742088,
        gas_used: 718517,
        value: 0
      }

  """
  def to_internal_transaction_params(call) when is_map(call) do
    call
    |> to_elixir()
    |> elixir_to_internal_transaction_params()
  end

  defp to_elixir(call) when is_map(call) do
    Enum.into(call, %{}, &entry_to_elixir/1)
  end

  defp entry_to_elixir({key, value} = entry)
       when key in ~w(callType createdContractAddressHash createdContractCode error from init input output to transactionHash type) and
              is_binary(value),
       do: entry

  defp entry_to_elixir({key, value} = entry) when key in ~w(blockNumber index transactionIndex) and is_integer(value),
    do: entry

  defp entry_to_elixir({key, quantity}) when key in ~w(gas gasUsed value) and is_binary(quantity) do
    {key, quantity_to_integer(quantity)}
  end

  defp entry_to_elixir({"traceAddress", trace_address} = entry) when is_list(trace_address) do
    true = Enum.all?(trace_address, &is_integer/1)

    entry
  end

  defp elixir_to_internal_transaction_params(%{
         "blockNumber" => block_number,
         "transactionIndex" => transaction_index,
         "transactionHash" => transaction_hash,
         "index" => index,
         "traceAddress" => trace_address,
         "type" => "call" = type,
         "callType" => call_type,
         "from" => from_address_hash,
         "to" => to_address_hash,
         "gas" => gas,
         "input" => input,
         "error" => error,
         "value" => value
       })
       when call_type in ~w(call callcode delegatecall) do
    %{
      block_number: block_number,
      transaction_index: transaction_index,
      transaction_hash: transaction_hash,
      index: index,
      trace_address: trace_address,
      type: type,
      call_type: call_type,
      from_address_hash: from_address_hash,
      to_address_hash: to_address_hash,
      gas: gas,
      input: input,
      error: error,
      value: value
    }
  end

  defp elixir_to_internal_transaction_params(%{
         "blockNumber" => block_number,
         "transactionIndex" => transaction_index,
         "transactionHash" => transaction_hash,
         "index" => index,
         "traceAddress" => trace_address,
         "type" => "call" = type,
         "callType" => call_type,
         "from" => from_address_hash,
         "to" => to_address_hash,
         "gas" => gas,
         "gasUsed" => gas_used,
         "input" => input,
         "output" => output,
         "value" => value
       })
       when call_type in ~w(call callcode delegatecall) do
    %{
      block_number: block_number,
      transaction_index: transaction_index,
      transaction_hash: transaction_hash,
      index: index,
      trace_address: trace_address,
      type: type,
      call_type: call_type,
      from_address_hash: from_address_hash,
      to_address_hash: to_address_hash,
      gas: gas,
      gas_used: gas_used,
      input: input,
      output: output,
      value: value
    }
  end

  defp elixir_to_internal_transaction_params(
         %{
           "blockNumber" => block_number,
           "transactionIndex" => transaction_index,
           "transactionHash" => transaction_hash,
           "index" => index,
           "traceAddress" => trace_address,
           "type" => "call" = type,
           "callType" => "staticcall" = call_type,
           "from" => from_address_hash,
           "to" => to_address_hash,
           "input" => input,
           "gas" => gas,
           "gasUsed" => gas_used,
           "value" => 0 = value
         } = params
       ) do
    %{
      block_number: block_number,
      transaction_index: transaction_index,
      transaction_hash: transaction_hash,
      index: index,
      trace_address: trace_address,
      type: type,
      call_type: call_type,
      from_address_hash: from_address_hash,
      to_address_hash: to_address_hash,
      gas: gas,
      gas_used: gas_used,
      input: input,
      output: params["output"],
      value: value
    }
  end

  defp elixir_to_internal_transaction_params(%{
         "blockNumber" => block_number,
         "transactionIndex" => transaction_index,
         "transactionHash" => transaction_hash,
         "index" => index,
         "traceAddress" => trace_address,
         "type" => type,
         "from" => from_address_hash,
         "error" => error,
         "gas" => gas,
         "init" => init,
         "value" => value
       })
       when type in ~w(create create2) do
    %{
      block_number: block_number,
      transaction_index: transaction_index,
      transaction_hash: transaction_hash,
      index: index,
      trace_address: trace_address,
      type: type,
      from_address_hash: from_address_hash,
      gas: gas,
      error: error,
      init: init,
      value: value
    }
  end

  defp elixir_to_internal_transaction_params(%{
         "blockNumber" => block_number,
         "transactionIndex" => transaction_index,
         "transactionHash" => transaction_hash,
         "index" => index,
         "traceAddress" => trace_address,
         "type" => type,
         "from" => from_address_hash,
         "createdContractAddressHash" => created_contract_address_hash,
         "gas" => gas,
         "gasUsed" => gas_used,
         "init" => init,
         "createdContractCode" => created_contract_code,
         "value" => value
       })
       when type in ~w(create create2) do
    %{
      block_number: block_number,
      transaction_index: transaction_index,
      transaction_hash: transaction_hash,
      index: index,
      trace_address: trace_address,
      type: type,
      from_address_hash: from_address_hash,
      gas: gas,
      gas_used: gas_used,
      created_contract_address_hash: created_contract_address_hash,
      init: init,
      created_contract_code: created_contract_code,
      value: value
    }
  end

  defp elixir_to_internal_transaction_params(%{
         "blockNumber" => block_number,
         "transactionIndex" => transaction_index,
         "transactionHash" => transaction_hash,
         "index" => index,
         "traceAddress" => trace_address,
         "type" => "selfdestruct" = type,
         "from" => from_address_hash,
         "to" => to_address_hash,
         "gas" => gas,
         "gasUsed" => gas_used,
         "value" => value
       }) do
    %{
      block_number: block_number,
      transaction_index: transaction_index,
      transaction_hash: transaction_hash,
      index: index,
      trace_address: trace_address,
      type: type,
      from_address_hash: from_address_hash,
      to_address_hash: to_address_hash,
      gas: gas,
      gas_used: gas_used,
      value: value
    }
  end
end
