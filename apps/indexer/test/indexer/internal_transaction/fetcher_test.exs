defmodule Indexer.InternalTransaction.FetcherTest do
  use EthereumJSONRPC.Case, async: false
  use Explorer.DataCase

  import ExUnit.CaptureLog
  import Mox

  alias Explorer.Chain.{Address, Hash, Transaction}

  alias Indexer.{CoinBalance, InternalTransaction, PendingTransaction}

  # MUST use global mode because we aren't guaranteed to get PendingTransactionFetcher's pid back fast enough to `allow`
  # it to use expectations and stubs from test's pid.
  setup :set_mox_global

  setup :verify_on_exit!

  @moduletag [capture_log: true, no_geth: true]

  test "does not try to fetch pending transactions from Indexer.PendingTransaction.Fetcher", %{
    json_rpc_named_arguments: json_rpc_named_arguments
  } do
    if json_rpc_named_arguments[:transport] == EthereumJSONRPC.Mox do
      case Keyword.fetch!(json_rpc_named_arguments, :variant) do
        EthereumJSONRPC.Parity ->
          EthereumJSONRPC.Mox
          |> expect(:json_rpc, fn _json, _options ->
            {:ok,
             [
               %{
                 "blockHash" => nil,
                 "blockNumber" => nil,
                 "chainId" => "0x4d",
                 "condition" => nil,
                 "creates" => "0xffc87239eb0267bc3ca2cd51d12fbf278e02ccb4",
                 "from" => "0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca",
                 "gas" => "0x47b760",
                 "gasPrice" => "0x174876e800",
                 "hash" => "0x3a3eb134e6792ce9403ea4188e5e79693de9e4c94e499db132be086400da79e6",
                 "input" =>
                   "0x6060604052341561000f57600080fd5b336000806101000a81548173ffffffffffffffffffffffffffffffffffffffff021916908373ffffffffffffffffffffffffffffffffffffffff1602179055506102db8061005e6000396000f300606060405260043610610062576000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff1680630900f01014610067578063445df0ac146100a05780638da5cb5b146100c9578063fdacd5761461011e575b600080fd5b341561007257600080fd5b61009e600480803573ffffffffffffffffffffffffffffffffffffffff16906020019091905050610141565b005b34156100ab57600080fd5b6100b3610224565b6040518082815260200191505060405180910390f35b34156100d457600080fd5b6100dc61022a565b604051808273ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff16815260200191505060405180910390f35b341561012957600080fd5b61013f600480803590602001909190505061024f565b005b60008060009054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff163373ffffffffffffffffffffffffffffffffffffffff161415610220578190508073ffffffffffffffffffffffffffffffffffffffff1663fdacd5766001546040518263ffffffff167c010000000000000000000000000000000000000000000000000000000002815260040180828152602001915050600060405180830381600087803b151561020b57600080fd5b6102c65a03f1151561021c57600080fd5b5050505b5050565b60015481565b6000809054906101000a900473ffffffffffffffffffffffffffffffffffffffff1681565b6000809054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff163373ffffffffffffffffffffffffffffffffffffffff1614156102ac57806001819055505b505600a165627a7a72305820a9c628775efbfbc17477a472413c01ee9b33881f550c59d21bee9928835c854b0029",
                 "nonce" => "0x0",
                 "publicKey" =>
                   "0xe5d196ad4ceada719d9e592f7166d0c75700f6eab2e3c3de34ba751ea786527cb3f6eb96ad9fdfdb9989ff572df50f1c42ef800af9c5207a38b929aff969b5c9",
                 "r" => "0xad3733df250c87556335ffe46c23e34dbaffde93097ef92f52c88632a40f0c75",
                 "raw" =>
                   "0xf9038d8085174876e8008347b7608080b903396060604052341561000f57600080fd5b336000806101000a81548173ffffffffffffffffffffffffffffffffffffffff021916908373ffffffffffffffffffffffffffffffffffffffff1602179055506102db8061005e6000396000f300606060405260043610610062576000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff1680630900f01014610067578063445df0ac146100a05780638da5cb5b146100c9578063fdacd5761461011e575b600080fd5b341561007257600080fd5b61009e600480803573ffffffffffffffffffffffffffffffffffffffff16906020019091905050610141565b005b34156100ab57600080fd5b6100b3610224565b6040518082815260200191505060405180910390f35b34156100d457600080fd5b6100dc61022a565b604051808273ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff16815260200191505060405180910390f35b341561012957600080fd5b61013f600480803590602001909190505061024f565b005b60008060009054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff163373ffffffffffffffffffffffffffffffffffffffff161415610220578190508073ffffffffffffffffffffffffffffffffffffffff1663fdacd5766001546040518263ffffffff167c010000000000000000000000000000000000000000000000000000000002815260040180828152602001915050600060405180830381600087803b151561020b57600080fd5b6102c65a03f1151561021c57600080fd5b5050505b5050565b60015481565b6000809054906101000a900473ffffffffffffffffffffffffffffffffffffffff1681565b6000809054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff163373ffffffffffffffffffffffffffffffffffffffff1614156102ac57806001819055505b505600a165627a7a72305820a9c628775efbfbc17477a472413c01ee9b33881f550c59d21bee9928835c854b002981bda0ad3733df250c87556335ffe46c23e34dbaffde93097ef92f52c88632a40f0c75a072caddc0371451a58de2ca6ab64e0f586ccdb9465ff54e1c82564940e89291e3",
                 "s" => "0x72caddc0371451a58de2ca6ab64e0f586ccdb9465ff54e1c82564940e89291e3",
                 "standardV" => "0x0",
                 "to" => nil,
                 "transactionIndex" => nil,
                 "v" => "0xbd",
                 "value" => "0x0"
               }
             ]}
          end)
          |> stub(:json_rpc, fn _json, _options ->
            {:ok, []}
          end)

        variant_name ->
          raise ArgumentError, "Unsupported variant name (#{variant_name})"
      end
    end

    CoinBalance.Supervisor.Case.start_supervised!(json_rpc_named_arguments: json_rpc_named_arguments)
    PendingTransaction.Supervisor.Case.start_supervised!(json_rpc_named_arguments: json_rpc_named_arguments)

    wait_for_results(fn ->
      Repo.one!(from(transaction in Explorer.Chain.Transaction, where: is_nil(transaction.block_hash), limit: 1))
    end)

    hash_strings =
      InternalTransaction.Fetcher.init([], fn hash_string, acc -> [hash_string | acc] end, json_rpc_named_arguments)

    assert :ok = InternalTransaction.Fetcher.run(hash_strings, json_rpc_named_arguments)
  end

  describe "init/2" do
    test "does not buffer pending transactions", %{json_rpc_named_arguments: json_rpc_named_arguments} do
      insert(:transaction)

      assert InternalTransaction.Fetcher.init(
               [],
               fn hash_string, acc -> [hash_string | acc] end,
               json_rpc_named_arguments
             ) == []
    end

    test "buffers collated transactions with unfetched internal transactions", %{
      json_rpc_named_arguments: json_rpc_named_arguments
    } do
      block = insert(:block)

      collated_unfetched_transaction =
        :transaction
        |> insert()
        |> with_block(block)

      assert InternalTransaction.Fetcher.init(
               [],
               fn hash_string, acc -> [hash_string | acc] end,
               json_rpc_named_arguments
             ) == [{block.number, collated_unfetched_transaction.hash.bytes, collated_unfetched_transaction.index}]
    end

    test "does not buffer collated transactions with fetched internal transactions", %{
      json_rpc_named_arguments: json_rpc_named_arguments
    } do
      :transaction
      |> insert()
      |> with_block(internal_transactions_indexed_at: DateTime.utc_now())

      assert InternalTransaction.Fetcher.init(
               [],
               fn hash_string, acc -> [hash_string | acc] end,
               json_rpc_named_arguments
             ) == []
    end
  end

  describe "run/2" do
    test "duplicate transaction hashes are logged", %{json_rpc_named_arguments: json_rpc_named_arguments} do
      if json_rpc_named_arguments[:transport] == EthereumJSONRPC.Mox do
        expect(EthereumJSONRPC.Mox, :json_rpc, fn _json, _options ->
          {:ok, [%{id: 0, result: %{"trace" => []}}]}
        end)
      end

      CoinBalance.Supervisor.Case.start_supervised!(json_rpc_named_arguments: json_rpc_named_arguments)

      %Transaction{hash: %Hash{bytes: bytes}} =
        insert(:transaction, hash: "0x03cd5899a63b6f6222afda8705d059fd5a7d126bcabe962fb654d9736e6bcafa")

      log =
        capture_log(fn ->
          InternalTransaction.Fetcher.run(
            [
              {1, bytes, 0},
              {1, bytes, 0}
            ],
            json_rpc_named_arguments
          )
        end)

      assert log =~
               """
               Duplicate entries being used to fetch internal transactions:
                 1. {1, <<3, 205, 88, 153, 166, 59, 111, 98, 34, 175, 218, 135, 5, 208, 89, 253, 90, 125, 18, 107, 202, 190, 150, 47, 182, 84, 217, 115, 110, 107, 202, 250>>, 0}
                 2. {1, <<3, 205, 88, 153, 166, 59, 111, 98, 34, 175, 218, 135, 5, 208, 89, 253, 90, 125, 18, 107, 202, 190, 150, 47, 182, 84, 217, 115, 110, 107, 202, 250>>, 0}
               """
    end

    @tag :no_parity
    test "internal transactions with failed parent does not create a new address", %{
      json_rpc_named_arguments: json_rpc_named_arguments
    } do
      if json_rpc_named_arguments[:transport] == EthereumJSONRPC.Mox do
        expect(EthereumJSONRPC.Mox, :json_rpc, fn _json, _options ->
          {:ok,
           [
             %{
               id: 0,
               jsonrpc: "2.0",
               result: %{
                 "output" => "0x",
                 "stateDiff" => nil,
                 "trace" => [
                   %{
                     "action" => %{
                       "callType" => "call",
                       "from" => "0xc73add416e2119d20ce80e0904fc1877e33ef246",
                       "gas" => "0x13388",
                       "input" => "0xc793bf97",
                       "to" => "0x2d07e106b5d280e4ccc2d10deee62441c91d4340",
                       "value" => "0x0"
                     },
                     "error" => "Reverted",
                     "subtraces" => 1,
                     "traceAddress" => [],
                     "type" => "call"
                   },
                   %{
                     "action" => %{
                       "from" => "0x2d07e106b5d280e4ccc2d10deee62441c91d4340",
                       "gas" => "0xb2ab",
                       "init" =>
                         "0x608060405234801561001057600080fd5b5060d38061001f6000396000f3fe6080604052600436106038577c010000000000000000000000000000000000000000000000000000000060003504633ccfd60b8114604f575b336000908152602081905260409020805434019055005b348015605a57600080fd5b5060616063565b005b33600081815260208190526040808220805490839055905190929183156108fc02918491818181858888f1935050505015801560a3573d6000803e3d6000fd5b505056fea165627a7a72305820e9a226f249def650de957dd8b4127b85a3049d6bfa818cadc4e2d3c44b6a53530029",
                       "value" => "0x0"
                     },
                     "result" => %{
                       "address" => "0xf4a5afe28b91cf928c2568805cfbb36d477f0b75",
                       "code" =>
                         "0x6080604052600436106038577c010000000000000000000000000000000000000000000000000000000060003504633ccfd60b8114604f575b336000908152602081905260409020805434019055005b348015605a57600080fd5b5060616063565b005b33600081815260208190526040808220805490839055905190929183156108fc02918491818181858888f1935050505015801560a3573d6000803e3d6000fd5b505056fea165627a7a72305820e9a226f249def650de957dd8b4127b85a3049d6bfa818cadc4e2d3c44b6a53530029",
                       "gasUsed" => "0xa535"
                     },
                     "subtraces" => 0,
                     "traceAddress" => [0],
                     "type" => "create"
                   }
                 ],
                 "vmTrace" => nil
               }
             }
           ]}
        end)

        CoinBalance.Supervisor.Case.start_supervised!(json_rpc_named_arguments: json_rpc_named_arguments)

        %Transaction{hash: %Hash{bytes: bytes}} =
          insert(:transaction, hash: "0x03cd5899a63b6f6222afda8705d059fd5a7d126bcabe962fb654d9736e6bcafa")
          |> with_block()

        :ok =
          InternalTransaction.Fetcher.run(
            [
              {7_202_692, bytes, 0}
            ],
            json_rpc_named_arguments
          )

        address = "0xf4a5afe28b91cf928c2568805cfbb36d477f0b75"

        fetched_address = Repo.one(from(address in Address, where: address.hash == ^address))

        assert is_nil(fetched_address)
      end
    end

    test "duplicate transaction hashes only retry uniques", %{json_rpc_named_arguments: json_rpc_named_arguments} do
      if json_rpc_named_arguments[:transport] == EthereumJSONRPC.Mox do
        expect(EthereumJSONRPC.Mox, :json_rpc, fn _json, _options ->
          {:ok, [%{id: 0, error: %{code: -32602, message: "Invalid params"}}]}
        end)
      end

      CoinBalance.Supervisor.Case.start_supervised!(json_rpc_named_arguments: json_rpc_named_arguments)

      # not a real transaction hash, so that fetch fails
      %Transaction{hash: %Hash{bytes: bytes}} =
        insert(:transaction, hash: "0x0000000000000000000000000000000000000000000000000000000000000001")

      assert InternalTransaction.Fetcher.run(
               [
                 {1, bytes, 0},
                 {1, bytes, 0}
               ],
               json_rpc_named_arguments
             ) == {:retry, [{1, bytes, 0}]}
    end
  end
end
