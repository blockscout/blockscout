defmodule Indexer.Temporary.AddressesWithoutCodeTest do
  use Explorer.DataCase, async: false
  use EthereumJSONRPC.Case, async: false

  import Mox

  import Ecto.Query

  alias Explorer.Repo
  alias Explorer.Chain.{Address, Transaction}
  alias Indexer.Temporary.AddressesWithoutCode.Supervisor
  alias Indexer.CoinBalance
  alias Indexer.Block.Fetcher
  alias Indexer.Block.Realtime.Fetcher, as: RealtimeFetcher
  alias Indexer.{CoinBalance, Code, InternalTransaction, ReplacedTransaction, Token, TokenBalance}

  @moduletag capture_log: true

  setup :set_mox_global

  setup :verify_on_exit!

  describe "run/1" do
    @tag :no_parity
    @tag :no_geth
    test "refetches blocks setting created address and code", %{json_rpc_named_arguments: json_rpc_named_arguments} do
      CoinBalance.Supervisor.Case.start_supervised!(json_rpc_named_arguments: json_rpc_named_arguments)
      Code.Supervisor.Case.start_supervised!(json_rpc_named_arguments: json_rpc_named_arguments)
      InternalTransaction.Supervisor.Case.start_supervised!(json_rpc_named_arguments: json_rpc_named_arguments)
      Token.Supervisor.Case.start_supervised!(json_rpc_named_arguments: json_rpc_named_arguments)
      TokenBalance.Supervisor.Case.start_supervised!(json_rpc_named_arguments: json_rpc_named_arguments)
      ReplacedTransaction.Supervisor.Case.start_supervised!()

      [name: Indexer.Block.Realtime.TaskSupervisor]
      |> Task.Supervisor.child_spec()
      |> ExUnit.Callbacks.start_supervised!()

      block = insert(:block)

      transaction =
        :transaction
        |> insert(
          status: 0,
          to_address: nil,
          created_contract_address_hash: nil,
          block: block,
          block_number: block.number,
          block_hash: block.hash,
          cumulative_gas_used: 200,
          gas_used: 100,
          index: 0
        )

      address = insert(:address, contract_code: nil)

      if json_rpc_named_arguments[:transport] == EthereumJSONRPC.Mox do
        EthereumJSONRPC.Mox
        |> expect(:json_rpc, fn [%{id: id, method: "eth_getBlockByNumber", params: [_block_quantity, true]}],
                                _options ->
          {:ok,
           [
             %{
               id: id,
               jsonrpc: "2.0",
               result: %{
                 "author" => "0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca",
                 "difficulty" => "0xfffffffffffffffffffffffffffffffe",
                 "extraData" => "0xd5830108048650617269747986312e32322e31826c69",
                 "gasLimit" => "0x69fe20",
                 "gasUsed" => "0xc512",
                 "hash" => "0xf6b4b8c88df3ebd252ec476328334dc026cf66606a84fb769b3d3cbccc8471bd",
                 "logsBloom" =>
                   "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000200000000000000000000020000000000000000200000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
                 "miner" => "0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca",
                 "number" => "0x25",
                 "parentHash" => "0xc37bbad7057945d1bf128c1ff009fb1ad632110bf6a000aac025a80f7766b66e",
                 "receiptsRoot" => "0xd300311aab7dcc98c05ac3f1893629b2c9082c189a0a0c76f4f63e292ac419d5",
                 "sealFields" => [
                   "0x84120a71de",
                   "0xb841fcdb570511ec61edda93849bb7c6b3232af60feb2ea74e4035f0143ab66dfdd00f67eb3eda1adddbb6b572db1e0abd39ce00f9b3ccacb9f47973279ff306fe5401"
                 ],
                 "sha3Uncles" => "0x1dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347",
                 "signature" =>
                   "fcdb570511ec61edda93849bb7c6b3232af60feb2ea74e4035f0143ab66dfdd00f67eb3eda1adddbb6b572db1e0abd39ce00f9b3ccacb9f47973279ff306fe5401",
                 "size" => "0x2cf",
                 "stateRoot" => "0x2cd84079b0d0c267ed387e3895fd1c1dc21ff82717beb1132adac64276886e19",
                 "step" => "302674398",
                 "timestamp" => "0x5a343956",
                 "totalDifficulty" => "0x24ffffffffffffffffffffffffedf78dfd",
                 "transactions" => [
                   %{
                     "blockHash" => "0xf6b4b8c88df3ebd252ec476328334dc026cf66606a84fb769b3d3cbccc8471bd",
                     "blockNumber" => "0x25",
                     "chainId" => "0x4d",
                     "condition" => "0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca",
                     "creates" => to_string(address.hash),
                     "from" => "0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca",
                     "to" => nil,
                     "gas" => "0x47b760",
                     "gasPrice" => "0x174876e800",
                     "hash" => to_string(transaction.hash),
                     "input" => "0x10855269000000000000000000000000862d67cb0773ee3f8ce7ea89b328ffea861ab3ef",
                     "nonce" => "0x4",
                     "publicKey" =>
                       "0xe5d196ad4ceada719d9e592f7166d0c75700f6eab2e3c3de34ba751ea786527cb3f6eb96ad9fdfdb9989ff572df50f1c42ef800af9c5207a38b929aff969b5c9",
                     "r" => "0xa7f8f45cce375bb7af8750416e1b03e0473f93c256da2285d1134fc97a700e01",
                     "raw" =>
                       "0xf88a0485174876e8008347b760948bf38d4764929064f2d4d3a56520a76ab3df415b80a410855269000000000000000000000000862d67cb0773ee3f8ce7ea89b328ffea861ab3ef81bea0a7f8f45cce375bb7af8750416e1b03e0473f93c256da2285d1134fc97a700e01a01f87a076f13824f4be8963e3dffd7300dae64d5f23c9a062af0c6ead347c135f",
                     "s" => "0x1f87a076f13824f4be8963e3dffd7300dae64d5f23c9a062af0c6ead347c135f",
                     "standardV" => "0x1",
                     "transactionIndex" => "0x0",
                     "v" => "0xbe",
                     "value" => "0x0"
                   }
                 ],
                 "transactionsRoot" => "0x68e314a05495f390f9cd0c36267159522e5450d2adf254a74567b452e767bf34",
                 "uncles" => []
               }
             }
           ]}
        end)
        |> expect(:json_rpc, fn [
                                  %{
                                    id: id,
                                    method: "eth_getTransactionReceipt",
                                    params: _
                                  }
                                ],
                                _options ->
          {:ok,
           [
             %{
               id: id,
               jsonrpc: "2.0",
               result: %{
                 "blockHash" => "0xf6b4b8c88df3ebd252ec476328334dc026cf66606a84fb769b3d3cbccc8471bd",
                 "blockNumber" => "0x25",
                 "contractAddress" => to_string(address.hash),
                 "cumulativeGasUsed" => "0xc512",
                 "gasUsed" => "0xc512",
                 "logs" => [
                   %{
                     "address" => "0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca",
                     "blockHash" => "0xf6b4b8c88df3ebd252ec476328334dc026cf66606a84fb769b3d3cbccc8471bd",
                     "blockNumber" => "0x25",
                     "data" => "0x000000000000000000000000862d67cb0773ee3f8ce7ea89b328ffea861ab3ef",
                     "logIndex" => "0x0",
                     "topics" => ["0x600bcf04a13e752d1e3670a5a9f1c21177ca2a93c6f5391d4f1298d098097c22"],
                     "transactionHash" => to_string(transaction.hash),
                     "transactionIndex" => "0x0",
                     "transactionLogIndex" => "0x0",
                     "type" => "mined"
                   }
                 ],
                 "logsBloom" =>
                   "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000200000000000000000000020000000000000000200000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
                 "root" => nil,
                 "status" => "0x1",
                 "transactionHash" => to_string(transaction.hash),
                 "transactionIndex" => "0x0"
               }
             }
           ]}
        end)
        |> expect(:json_rpc, fn [%{id: id, method: "trace_block", params: _}], _options ->
          {:ok, [%{id: id, result: []}]}
        end)
        |> expect(:json_rpc, fn [%{id: id, method: "trace_replayBlockTransactions", params: _}], _options ->
          {:ok, [%{id: id, result: []}]}
        end)
        |> expect(:json_rpc, fn [
                                  %{
                                    id: 0,
                                    jsonrpc: "2.0",
                                    method: "eth_getBalance",
                                    params: ["0x0000000000000000000000000000000000000003", "0x25"]
                                  },
                                  %{
                                    id: 1,
                                    jsonrpc: "2.0",
                                    method: "eth_getBalance",
                                    params: ["0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca", "0x25"]
                                  }
                                ],
                                _options ->
          {:ok, [%{id: 0, jsonrpc: "2.0", result: "0x0"}, %{id: 1, jsonrpc: "2.0", result: "0x0"}]}
        end)
      end

      fetcher = %Fetcher{
        broadcast: false,
        callback_module: RealtimeFetcher,
        json_rpc_named_arguments: json_rpc_named_arguments
      }

      [fetcher, [name: AddressesWithoutCodeTest]]
      |> Supervisor.child_spec()
      |> ExUnit.Callbacks.start_supervised!()

      Process.sleep(2_000)

      updated_address =
        from(a in Address, where: a.hash == ^address.hash, preload: :contracts_creation_transaction) |> Repo.one()

      assert updated_address.contracts_creation_transaction.hash == transaction.hash

      updated_transaction =
        from(t in Transaction, where: t.hash == ^transaction.hash, preload: :created_contract_address) |> Repo.one()

      assert updated_transaction.created_contract_address.hash == address.hash
    end
  end
end
