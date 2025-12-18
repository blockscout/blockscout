defmodule Indexer.Fetcher.OnDemand.InternalTransactionTest do
  use EthereumJSONRPC.Case, async: false
  use Explorer.DataCase

  import Mox

  alias Explorer.Chain.InternalTransaction
  alias Explorer.PagingOptions
  alias Indexer.Fetcher.OnDemand.InternalTransaction, as: InternalTransactionOnDemand

  setup :set_mox_global

  setup :verify_on_exit!

  setup do
    initial_ethereum_jsonrpc_env = Application.get_all_env(:ethereum_jsonrpc)
    initial_json_rpc_named_arguments = Application.get_env(:explorer, :json_rpc_named_arguments)
    %{json_rpc_named_arguments: json_rpc_named_arguments} = EthereumJSONRPC.Case.Geth.Mox.setup()
    Application.put_env(:explorer, :json_rpc_named_arguments, json_rpc_named_arguments)

    on_exit(fn ->
      Application.put_all_env([{:ethereum_jsonrpc, initial_ethereum_jsonrpc_env}])
      Application.put_env(:explorer, :json_rpc_named_arguments, initial_json_rpc_named_arguments)
    end)
  end

  test "fetch_by_transaction/2" do
    transaction = :transaction |> insert() |> with_block()
    block_hash = transaction.block_hash

    expect(EthereumJSONRPC.Mox, :json_rpc, 1, fn
      [%{id: id, params: _}], _ ->
        {:ok,
         [
           %{
             id: id,
             result: %{
               "type" => "create",
               "from" => "0x117b358218da5a4f647072ddb50ded038ed63d17",
               "to" => "0x205a6b72ce16736c9d87172568a9c0cb9304de0d",
               "value" => "0x0",
               "gas" => "0x106f5",
               "gasUsed" => "0x106f5",
               "input" =>
                 "0x608060405234801561001057600080fd5b50610150806100206000396000f3fe608060405234801561001057600080fd5b50600436106100365760003560e01c80632e64cec11461003b5780636057361d14610059575b600080fd5b610043610075565b60405161005091906100d9565b60405180910390f35b610073600480360381019061006e919061009d565b61007e565b005b60008054905090565b8060008190555050565b60008135905061009781610103565b92915050565b6000602082840312156100b3576100b26100fe565b5b60006100c184828501610088565b91505092915050565b6100d3816100f4565b82525050565b60006020820190506100ee60008301846100ca565b92915050565b6000819050919050565b600080fd5b61010c816100f4565b811461011757600080fd5b5056fea26469706673582212209a159a4f3847890f10bfb87871a61eba91c5dbf5ee3cf6398207e292eee22a1664736f6c63430008070033",
               "output" =>
                 "0x608060405234801561001057600080fd5b50600436106100365760003560e01c80632e64cec11461003b5780636057361d14610059575b600080fd5b610043610075565b60405161005091906100d9565b60405180910390f35b610073600480360381019061006e919061009d565b61007e565b005b60008054905090565b8060008190555050565b60008135905061009781610103565b92915050565b6000602082840312156100b3576100b26100fe565b5b60006100c184828501610088565b91505092915050565b6100d3816100f4565b82525050565b60006020820190506100ee60008301846100ca565b92915050565b6000819050919050565b600080fd5b61010c816100f4565b811461011757600080fd5b5056fea26469706673582212209a159a4f3847890f10bfb87871a61eba91c5dbf5ee3cf6398207e292eee22a1664736f6c63430008070033"
             }
           }
         ]}
    end)

    Application.put_env(:ethereum_jsonrpc, EthereumJSONRPC.Geth, tracer: "call_tracer", debug_trace_timeout: "5s")

    opts = [
      necessity_by_association: %{
        [transaction: [:from_address]] => :required
      }
    ]

    assert [
             %InternalTransaction{
               created_contract_address_hash: created_contract_address_hash,
               from_address_hash: from_address_hash,
               transaction: %{from_address: %{}, block_hash: ^block_hash}
             }
           ] = InternalTransactionOnDemand.fetch_by_transaction(transaction, opts)

    assert to_string(created_contract_address_hash) == "0x205a6b72ce16736c9d87172568a9c0cb9304de0d"
    assert to_string(from_address_hash) == "0x117b358218da5a4f647072ddb50ded038ed63d17"
  end

  test "fetch_by_block/2" do
    block = build(:block)
    block_quantity = EthereumJSONRPC.integer_to_quantity(block.number)
    block_hash = block.hash

    expect(EthereumJSONRPC.Mox, :json_rpc, fn [%{id: id, params: [^block_quantity, _]}], _ ->
      {:ok,
       [
         %{
           id: id,
           result: [
             %{
               "result" => %{
                 "calls" => [
                   %{
                     "from" => "0x4200000000000000000000000000000000000015",
                     "gas" => "0xe9a3c",
                     "gasUsed" => "0x4a28",
                     "input" =>
                       "0x015d8eb900000000000000000000000000000000000000000000000000000000009cb0d80000000000000000000000000000000000000000000000000000000065898738000000000000000000000000000000000000000000000000000000000000001b65f7961a6893850c1f001edeaa0aa4f1fb36b67eee61a8623f8f4da81be25c0000000000000000000000000000000000000000000000000000000000000000050000000000000000000000007431310e026b69bfc676c0013e12a1a11411eec9000000000000000000000000000000000000000000000000000000000000083400000000000000000000000000000000000000000000000000000000000f4240",
                     "to" => "0x6df83a19647a398d48e77a6835f4a28eb7e2f7c0",
                     "type" => "DELEGATECALL",
                     "value" => "0x0"
                   }
                 ],
                 "from" => "0xdeaddeaddeaddeaddeaddeaddeaddeaddead0001",
                 "gas" => "0xf4240",
                 "gasUsed" => "0xb6f9",
                 "input" =>
                   "0x015d8eb900000000000000000000000000000000000000000000000000000000009cb0d80000000000000000000000000000000000000000000000000000000065898738000000000000000000000000000000000000000000000000000000000000001b65f7961a6893850c1f001edeaa0aa4f1fb36b67eee61a8623f8f4da81be25c0000000000000000000000000000000000000000000000000000000000000000050000000000000000000000007431310e026b69bfc676c0013e12a1a11411eec9000000000000000000000000000000000000000000000000000000000000083400000000000000000000000000000000000000000000000000000000000f4240",
                 "to" => "0x4200000000000000000000000000000000000015",
                 "type" => "CALL",
                 "value" => "0x0"
               },
               "txHash" => "0x32b17f27ddb546eab3c4c33f31eb22c1cb992d4ccc50dae26922805b717efe5c"
             }
           ]
         }
       ]}
    end)

    Application.put_env(:ethereum_jsonrpc, EthereumJSONRPC.Geth,
      tracer: "call_tracer",
      debug_trace_timeout: "5s",
      block_traceable?: true
    )

    assert [%InternalTransaction{block_hash: ^block_hash, index: 1}] =
             InternalTransactionOnDemand.fetch_by_block(block, [])
  end

  test "fetch_by_block/2 (block_traceable?: false)" do
    transaction = :transaction |> insert() |> with_block()
    transaction_hash_str = to_string(transaction.hash)
    block_hash = transaction.block_hash

    expect(EthereumJSONRPC.Mox, :json_rpc, fn [%{id: id, params: [^transaction_hash_str, _]}], _ ->
      {:ok,
       [
         %{
           id: id,
           result: %{
             "calls" => [
               %{
                 "from" => "0x4200000000000000000000000000000000000015",
                 "gas" => "0xe9a3c",
                 "gasUsed" => "0x4a28",
                 "input" =>
                   "0x015d8eb900000000000000000000000000000000000000000000000000000000009cb0d80000000000000000000000000000000000000000000000000000000065898738000000000000000000000000000000000000000000000000000000000000001b65f7961a6893850c1f001edeaa0aa4f1fb36b67eee61a8623f8f4da81be25c0000000000000000000000000000000000000000000000000000000000000000050000000000000000000000007431310e026b69bfc676c0013e12a1a11411eec9000000000000000000000000000000000000000000000000000000000000083400000000000000000000000000000000000000000000000000000000000f4240",
                 "to" => "0x6df83a19647a398d48e77a6835f4a28eb7e2f7c0",
                 "type" => "DELEGATECALL",
                 "value" => "0x0"
               }
             ],
             "from" => "0xdeaddeaddeaddeaddeaddeaddeaddeaddead0001",
             "gas" => "0xf4240",
             "gasUsed" => "0xb6f9",
             "input" =>
               "0x015d8eb900000000000000000000000000000000000000000000000000000000009cb0d80000000000000000000000000000000000000000000000000000000065898738000000000000000000000000000000000000000000000000000000000000001b65f7961a6893850c1f001edeaa0aa4f1fb36b67eee61a8623f8f4da81be25c0000000000000000000000000000000000000000000000000000000000000000050000000000000000000000007431310e026b69bfc676c0013e12a1a11411eec9000000000000000000000000000000000000000000000000000000000000083400000000000000000000000000000000000000000000000000000000000f4240",
             "to" => "0x4200000000000000000000000000000000000015",
             "type" => "CALL",
             "value" => "0x0"
           }
         }
       ]}
    end)

    Application.put_env(:ethereum_jsonrpc, EthereumJSONRPC.Geth,
      tracer: "call_tracer",
      debug_trace_timeout: "5s",
      block_traceable?: false
    )

    assert [%InternalTransaction{block_hash: ^block_hash, index: 1}] =
             InternalTransactionOnDemand.fetch_by_block(transaction.block, [])
  end

  test "fetch_by_address/2" do
    address = insert(:address)
    address_hash_str = to_string(address.hash)
    id_to_hash = insert(:address_id_to_address_hash, address_hash: address.hash)

    insert(:deleted_internal_transactions_address_placeholder,
      address_id: id_to_hash.address_id,
      block_number: 1,
      count_tos: 1,
      count_froms: 1
    )

    insert(:deleted_internal_transactions_address_placeholder,
      address_id: id_to_hash.address_id,
      block_number: 2,
      count_tos: 2,
      count_froms: 2
    )

    insert(:deleted_internal_transactions_address_placeholder,
      address_id: id_to_hash.address_id,
      block_number: 3,
      count_tos: 3,
      count_froms: 3
    )

    expect(EthereumJSONRPC.Mox, :json_rpc, fn
      [
        %{id: id_1, params: ["0x3", _]},
        %{id: id_2, params: ["0x2", _]}
      ],
      _ ->
        {:ok,
         [
           %{
             id: id_1,
             result: [
               %{
                 "result" => %{
                   "calls" => [
                     %{
                       "from" => "0x4200000000000000000000000000000000000015",
                       "gas" => "0xe9a3c",
                       "gasUsed" => "0x4a28",
                       "input" =>
                         "0x015d8eb900000000000000000000000000000000000000000000000000000000009cb0d80000000000000000000000000000000000000000000000000000000065898738000000000000000000000000000000000000000000000000000000000000001b65f7961a6893850c1f001edeaa0aa4f1fb36b67eee61a8623f8f4da81be25c0000000000000000000000000000000000000000000000000000000000000000050000000000000000000000007431310e026b69bfc676c0013e12a1a11411eec9000000000000000000000000000000000000000000000000000000000000083400000000000000000000000000000000000000000000000000000000000f4240",
                       "to" => address_hash_str,
                       "type" => "CALL",
                       "value" => "0x0"
                     }
                   ],
                   "from" => "0xdeaddeaddeaddeaddeaddeaddeaddeaddead0001",
                   "gas" => "0xf4240",
                   "gasUsed" => "0xb6f9",
                   "input" =>
                     "0x015d8eb900000000000000000000000000000000000000000000000000000000009cb0d80000000000000000000000000000000000000000000000000000000065898738000000000000000000000000000000000000000000000000000000000000001b65f7961a6893850c1f001edeaa0aa4f1fb36b67eee61a8623f8f4da81be25c0000000000000000000000000000000000000000000000000000000000000000050000000000000000000000007431310e026b69bfc676c0013e12a1a11411eec9000000000000000000000000000000000000000000000000000000000000083400000000000000000000000000000000000000000000000000000000000f4240",
                   "to" => address_hash_str,
                   "type" => "CALL",
                   "value" => "0x0"
                 },
                 "txHash" => "0x32b17f27ddb546eab3c4c33f31eb22c1cb992d4ccc50dae26922805b717efe5c"
               },
               %{
                 "result" => %{
                   "calls" => [
                     %{
                       "from" => "0x4200000000000000000000000000000000000015",
                       "gas" => "0xe9a3c",
                       "gasUsed" => "0x4a28",
                       "input" =>
                         "0x015d8eb900000000000000000000000000000000000000000000000000000000009cb0d80000000000000000000000000000000000000000000000000000000065898738000000000000000000000000000000000000000000000000000000000000001b65f7961a6893850c1f001edeaa0aa4f1fb36b67eee61a8623f8f4da81be25c0000000000000000000000000000000000000000000000000000000000000000050000000000000000000000007431310e026b69bfc676c0013e12a1a11411eec9000000000000000000000000000000000000000000000000000000000000083400000000000000000000000000000000000000000000000000000000000f4240",
                       "to" => address_hash_str,
                       "type" => "CALL",
                       "value" => "0x0"
                     }
                   ],
                   "from" => "0xdeaddeaddeaddeaddeaddeaddeaddeaddead0001",
                   "gas" => "0xf4240",
                   "gasUsed" => "0xb6f9",
                   "input" =>
                     "0x015d8eb900000000000000000000000000000000000000000000000000000000009cb0d80000000000000000000000000000000000000000000000000000000065898738000000000000000000000000000000000000000000000000000000000000001b65f7961a6893850c1f001edeaa0aa4f1fb36b67eee61a8623f8f4da81be25c0000000000000000000000000000000000000000000000000000000000000000050000000000000000000000007431310e026b69bfc676c0013e12a1a11411eec9000000000000000000000000000000000000000000000000000000000000083400000000000000000000000000000000000000000000000000000000000f4240",
                   "to" => address_hash_str,
                   "type" => "CALL",
                   "value" => "0x0"
                 },
                 "txHash" => "0x32b17f27ddb546eab3c4c33f31eb22c1cb992d4ccc50dae26922805b717efe5d"
               },
               %{
                 "result" => %{
                   "calls" => [
                     %{
                       "from" => "0x4200000000000000000000000000000000000015",
                       "gas" => "0xe9a3c",
                       "gasUsed" => "0x4a28",
                       "input" =>
                         "0x015d8eb900000000000000000000000000000000000000000000000000000000009cb0d80000000000000000000000000000000000000000000000000000000065898738000000000000000000000000000000000000000000000000000000000000001b65f7961a6893850c1f001edeaa0aa4f1fb36b67eee61a8623f8f4da81be25c0000000000000000000000000000000000000000000000000000000000000000050000000000000000000000007431310e026b69bfc676c0013e12a1a11411eec9000000000000000000000000000000000000000000000000000000000000083400000000000000000000000000000000000000000000000000000000000f4240",
                       "to" => address_hash_str,
                       "type" => "CALL",
                       "value" => "0x0"
                     }
                   ],
                   "from" => "0xdeaddeaddeaddeaddeaddeaddeaddeaddead0001",
                   "gas" => "0xf4240",
                   "gasUsed" => "0xb6f9",
                   "input" =>
                     "0x015d8eb900000000000000000000000000000000000000000000000000000000009cb0d80000000000000000000000000000000000000000000000000000000065898738000000000000000000000000000000000000000000000000000000000000001b65f7961a6893850c1f001edeaa0aa4f1fb36b67eee61a8623f8f4da81be25c0000000000000000000000000000000000000000000000000000000000000000050000000000000000000000007431310e026b69bfc676c0013e12a1a11411eec9000000000000000000000000000000000000000000000000000000000000083400000000000000000000000000000000000000000000000000000000000f4240",
                   "to" => address_hash_str,
                   "type" => "CALL",
                   "value" => "0x0"
                 },
                 "txHash" => "0x32b17f27ddb546eab3c4c33f31eb22c1cb992d4ccc50dae26922805b717efe5e"
               }
             ]
           },
           %{
             id: id_2,
             result: [
               %{
                 "result" => %{
                   "calls" => [
                     %{
                       "from" => "0x4200000000000000000000000000000000000015",
                       "gas" => "0xe9a3c",
                       "gasUsed" => "0x4a28",
                       "input" =>
                         "0x015d8eb900000000000000000000000000000000000000000000000000000000009cb0d80000000000000000000000000000000000000000000000000000000065898738000000000000000000000000000000000000000000000000000000000000001b65f7961a6893850c1f001edeaa0aa4f1fb36b67eee61a8623f8f4da81be25c0000000000000000000000000000000000000000000000000000000000000000050000000000000000000000007431310e026b69bfc676c0013e12a1a11411eec9000000000000000000000000000000000000000000000000000000000000083400000000000000000000000000000000000000000000000000000000000f4240",
                       "to" => address_hash_str,
                       "type" => "CALL",
                       "value" => "0x0"
                     }
                   ],
                   "from" => "0xdeaddeaddeaddeaddeaddeaddeaddeaddead0001",
                   "gas" => "0xf4240",
                   "gasUsed" => "0xb6f9",
                   "input" =>
                     "0x015d8eb900000000000000000000000000000000000000000000000000000000009cb0d80000000000000000000000000000000000000000000000000000000065898738000000000000000000000000000000000000000000000000000000000000001b65f7961a6893850c1f001edeaa0aa4f1fb36b67eee61a8623f8f4da81be25c0000000000000000000000000000000000000000000000000000000000000000050000000000000000000000007431310e026b69bfc676c0013e12a1a11411eec9000000000000000000000000000000000000000000000000000000000000083400000000000000000000000000000000000000000000000000000000000f4240",
                   "to" => address_hash_str,
                   "type" => "CALL",
                   "value" => "0x0"
                 },
                 "txHash" => "0x32b17f27ddb546eab3c4c33f31eb22c1cb992d4ccc50dae26922805b717efe5f"
               },
               %{
                 "result" => %{
                   "calls" => [
                     %{
                       "from" => "0x4200000000000000000000000000000000000015",
                       "gas" => "0xe9a3c",
                       "gasUsed" => "0x4a28",
                       "input" =>
                         "0x015d8eb900000000000000000000000000000000000000000000000000000000009cb0d80000000000000000000000000000000000000000000000000000000065898738000000000000000000000000000000000000000000000000000000000000001b65f7961a6893850c1f001edeaa0aa4f1fb36b67eee61a8623f8f4da81be25c0000000000000000000000000000000000000000000000000000000000000000050000000000000000000000007431310e026b69bfc676c0013e12a1a11411eec9000000000000000000000000000000000000000000000000000000000000083400000000000000000000000000000000000000000000000000000000000f4240",
                       "to" => address_hash_str,
                       "type" => "CALL",
                       "value" => "0x0"
                     }
                   ],
                   "from" => "0xdeaddeaddeaddeaddeaddeaddeaddeaddead0001",
                   "gas" => "0xf4240",
                   "gasUsed" => "0xb6f9",
                   "input" =>
                     "0x015d8eb900000000000000000000000000000000000000000000000000000000009cb0d80000000000000000000000000000000000000000000000000000000065898738000000000000000000000000000000000000000000000000000000000000001b65f7961a6893850c1f001edeaa0aa4f1fb36b67eee61a8623f8f4da81be25c0000000000000000000000000000000000000000000000000000000000000000050000000000000000000000007431310e026b69bfc676c0013e12a1a11411eec9000000000000000000000000000000000000000000000000000000000000083400000000000000000000000000000000000000000000000000000000000f4240",
                   "to" => address_hash_str,
                   "type" => "CALL",
                   "value" => "0x0"
                 },
                 "txHash" => "0x32b17f27ddb546eab3c4c33f31eb22c1cb992d4ccc50dae26922805b717efe5b"
               }
             ]
           }
         ]}
    end)

    Application.put_env(:ethereum_jsonrpc, EthereumJSONRPC.Geth,
      tracer: "call_tracer",
      debug_trace_timeout: "5s",
      block_traceable?: true
    )

    opts = [
      direction: :to_address_hash,
      paging_options: %PagingOptions{page_size: 4}
    ]

    assert [%InternalTransaction{}, %InternalTransaction{}, %InternalTransaction{}, %InternalTransaction{}] =
             result = InternalTransactionOnDemand.fetch_by_address(address.hash, opts)

    assert result |> Enum.filter(&(&1.block_number == 3)) |> Enum.count() == 3
    assert result |> Enum.filter(&(&1.block_number == 2)) |> Enum.count() == 1
  end
end
