defmodule Indexer.Block.Catchup.FetcherTest do
  use EthereumJSONRPC.Case, async: false
  use Explorer.DataCase

  import EthereumJSONRPC, only: [integer_to_quantity: 1]
  import Mox

  alias Explorer.Chain
  alias Explorer.Chain.Block.Reward
  alias Indexer.Block
  alias Indexer.Block.Catchup.Fetcher
  alias Indexer.Fetcher.{BlockReward, CoinBalance, InternalTransaction, Token, TokenBalance, UncleBlock}

  @moduletag capture_log: true

  # MUST use global mode because we aren't guaranteed to get `start_supervised`'s pid back fast enough to `allow` it to
  # use expectations and stubs from test's pid.
  setup :set_mox_global

  setup :verify_on_exit!

  setup do
    # Uncle don't occur on POA chains, so there's no way to test this using the public addresses, so mox-only testing
    %{
      json_rpc_named_arguments: [
        transport: EthereumJSONRPC.Mox,
        transport_options: [],
        # Which one does not matter, so pick one
        variant: EthereumJSONRPC.Parity
      ]
    }
  end

  describe "import/1" do
    test "fetches uncles asynchronously", %{json_rpc_named_arguments: json_rpc_named_arguments} do
      CoinBalance.Supervisor.Case.start_supervised!(json_rpc_named_arguments: json_rpc_named_arguments)
      InternalTransaction.Supervisor.Case.start_supervised!(json_rpc_named_arguments: json_rpc_named_arguments)
      Token.Supervisor.Case.start_supervised!(json_rpc_named_arguments: json_rpc_named_arguments)
      TokenBalance.Supervisor.Case.start_supervised!(json_rpc_named_arguments: json_rpc_named_arguments)

      parent = self()

      pid =
        spawn_link(fn ->
          receive do
            {:"$gen_call", from, {:buffer, uncles}} ->
              GenServer.reply(from, :ok)
              send(parent, {:uncles, uncles})
          end
        end)

      Process.register(pid, UncleBlock)

      nephew_hash = block_hash() |> to_string()
      uncle_hash = block_hash() |> to_string()
      miner_hash = address_hash() |> to_string()
      block_number = 0

      assert {:ok, _} =
               Fetcher.import(%Block.Fetcher{json_rpc_named_arguments: json_rpc_named_arguments}, %{
                 addresses: %{
                   params: [
                     %{hash: miner_hash}
                   ]
                 },
                 address_hash_to_fetched_balance_block_number: %{miner_hash => block_number},
                 address_coin_balances: %{
                   params: [
                     %{
                       address_hash: miner_hash,
                       block_number: block_number
                     }
                   ]
                 },
                 blocks: %{
                   params: [
                     %{
                       difficulty: 0,
                       gas_limit: 21000,
                       gas_used: 21000,
                       miner_hash: miner_hash,
                       nonce: 0,
                       number: block_number,
                       parent_hash:
                         block_hash()
                         |> to_string(),
                       size: 0,
                       timestamp: DateTime.utc_now(),
                       total_difficulty: 0,
                       hash: nephew_hash
                     }
                   ]
                 },
                 block_rewards: %{errors: [], params: []},
                 block_second_degree_relations: %{
                   params: [
                     %{
                       nephew_hash: nephew_hash,
                       uncle_hash: uncle_hash
                     }
                   ]
                 },
                 tokens: %{
                   params: [],
                   on_conflict: :nothing
                 },
                 address_token_balances: %{
                   params: []
                 },
                 transactions: %{
                   params: [],
                   on_conflict: :nothing
                 }
               })

      assert_receive {:uncles, [^uncle_hash]}
    end
  end

  describe "task/1" do
    test "ignores fetched beneficiaries with different hash for same number", %{
      json_rpc_named_arguments: json_rpc_named_arguments
    } do
      CoinBalance.Supervisor.Case.start_supervised!(json_rpc_named_arguments: json_rpc_named_arguments)
      InternalTransaction.Supervisor.Case.start_supervised!(json_rpc_named_arguments: json_rpc_named_arguments)
      Token.Supervisor.Case.start_supervised!(json_rpc_named_arguments: json_rpc_named_arguments)
      TokenBalance.Supervisor.Case.start_supervised!(json_rpc_named_arguments: json_rpc_named_arguments)

      latest_block_number = 1
      latest_block_quantity = integer_to_quantity(latest_block_number)

      block_number = latest_block_number - 1
      block_hash = block_hash()
      block_quantity = integer_to_quantity(block_number)

      miner_hash = address_hash()
      miner_hash_data = to_string(miner_hash)

      new_block_hash = block_hash()

      refute block_hash == new_block_hash

      EthereumJSONRPC.Mox
      |> expect(:json_rpc, fn %{method: "eth_getBlockByNumber", params: ["latest", false]}, _options ->
        {:ok, %{"number" => latest_block_quantity}}
      end)
      |> expect(:json_rpc, fn [
                                %{
                                  id: id,
                                  jsonrpc: "2.0",
                                  method: "eth_getBlockByNumber",
                                  params: [^block_quantity, true]
                                }
                              ],
                              _options ->
        {:ok,
         [
           %{
             id: id,
             jsonrpc: "2.0",
             result: %{
               "hash" => to_string(block_hash),
               "number" => block_quantity,
               "difficulty" => "0x0",
               "gasLimit" => "0x0",
               "gasUsed" => "0x0",
               "extraData" => "0x0",
               "logsBloom" => "0x0",
               "miner" => miner_hash_data,
               "parentHash" =>
                 block_hash()
                 |> to_string(),
               "receiptsRoot" => "0x0",
               "size" => "0x0",
               "sha3Uncles" => "0x0",
               "stateRoot" => "0x0",
               "timestamp" => "0x0",
               "totalDifficulty" => "0x0",
               "transactions" => [],
               "transactionsRoot" => "0x0",
               "uncles" => []
             }
           }
         ]}
      end)
      |> expect(:json_rpc, fn [%{id: id, jsonrpc: "2.0", method: "trace_block", params: [^block_quantity]}], _options ->
        {
          :ok,
          [
            %{
              id: id,
              jsonrpc: "2.0",
              result: [
                %{
                  "action" => %{
                    "author" => miner_hash_data,
                    "rewardType" => "external",
                    "value" => "0x0"
                  },
                  "blockHash" => to_string(new_block_hash),
                  "blockNumber" => block_number,
                  "result" => nil,
                  "subtraces" => 0,
                  "traceAddress" => [],
                  "transactionHash" => nil,
                  "transactionPosition" => nil,
                  "type" => "reward"
                }
              ]
            }
          ]
        }
      end)

      assert count(Chain.Block) == 0

      assert %{first_block_number: ^block_number, missing_block_count: 1, shrunk: false} =
               Fetcher.task(%Fetcher{
                 blocks_batch_size: 1,
                 block_fetcher: %Block.Fetcher{
                   callback_module: Fetcher,
                   json_rpc_named_arguments: json_rpc_named_arguments
                 }
               })

      assert count(Chain.Block) == 1
      assert count(Reward) == 0
    end

    test "async fetches beneficiaries when individual responses error out", %{
      json_rpc_named_arguments: json_rpc_named_arguments
    } do
      CoinBalance.Supervisor.Case.start_supervised!(json_rpc_named_arguments: json_rpc_named_arguments)
      InternalTransaction.Supervisor.Case.start_supervised!(json_rpc_named_arguments: json_rpc_named_arguments)
      Token.Supervisor.Case.start_supervised!(json_rpc_named_arguments: json_rpc_named_arguments)
      TokenBalance.Supervisor.Case.start_supervised!(json_rpc_named_arguments: json_rpc_named_arguments)

      latest_block_number = 1
      latest_block_quantity = integer_to_quantity(latest_block_number)

      block_number = latest_block_number - 1
      block_hash = block_hash()
      block_quantity = integer_to_quantity(block_number)

      miner_hash = address_hash()
      miner_hash_data = to_string(miner_hash)

      new_block_hash = block_hash()

      refute block_hash == new_block_hash

      EthereumJSONRPC.Mox
      |> expect(:json_rpc, fn %{method: "eth_getBlockByNumber", params: ["latest", false]}, _options ->
        {:ok, %{"number" => latest_block_quantity}}
      end)
      |> expect(:json_rpc, fn [
                                %{
                                  id: id,
                                  jsonrpc: "2.0",
                                  method: "eth_getBlockByNumber",
                                  params: [^block_quantity, true]
                                }
                              ],
                              _options ->
        {:ok,
         [
           %{
             id: id,
             jsonrpc: "2.0",
             result: %{
               "hash" => to_string(block_hash),
               "number" => block_quantity,
               "difficulty" => "0x0",
               "gasLimit" => "0x0",
               "gasUsed" => "0x0",
               "extraData" => "0x0",
               "logsBloom" => "0x0",
               "miner" => miner_hash_data,
               "parentHash" =>
                 block_hash()
                 |> to_string(),
               "receiptsRoot" => "0x0",
               "size" => "0x0",
               "sha3Uncles" => "0x0",
               "stateRoot" => "0x0",
               "timestamp" => "0x0",
               "totalDifficulty" => "0x0",
               "transactions" => [],
               "transactionsRoot" => "0x0",
               "uncles" => []
             }
           }
         ]}
      end)
      |> expect(:json_rpc, fn [%{id: id, method: "trace_block", params: [^block_quantity]}], _options ->
        {:ok,
         [
           %{
             id: id,
             jsonrpc: "2.0",
             result: nil
           }
         ]}
      end)

      assert count(Chain.Block) == 0

      parent = self()

      pid =
        spawn_link(fn ->
          receive do
            {:"$gen_call", from, {:buffer, block_numbers}} ->
              GenServer.reply(from, :ok)
              send(parent, {:block_numbers, block_numbers})
          end
        end)

      Process.register(pid, BlockReward)

      assert %{first_block_number: ^block_number, missing_block_count: 1, shrunk: false} =
               Fetcher.task(%Fetcher{
                 blocks_batch_size: 1,
                 block_fetcher: %Block.Fetcher{
                   callback_module: Fetcher,
                   json_rpc_named_arguments: json_rpc_named_arguments
                 }
               })

      assert count(Chain.Block) == 1
      assert count(Reward) == 0

      assert_receive {:block_numbers, [block_number]}, 5_000
    end

    test "async fetches beneficiaries when entire call errors out", %{
      json_rpc_named_arguments: json_rpc_named_arguments
    } do
      CoinBalance.Supervisor.Case.start_supervised!(json_rpc_named_arguments: json_rpc_named_arguments)
      InternalTransaction.Supervisor.Case.start_supervised!(json_rpc_named_arguments: json_rpc_named_arguments)
      Token.Supervisor.Case.start_supervised!(json_rpc_named_arguments: json_rpc_named_arguments)
      TokenBalance.Supervisor.Case.start_supervised!(json_rpc_named_arguments: json_rpc_named_arguments)

      latest_block_number = 1
      latest_block_quantity = integer_to_quantity(latest_block_number)

      block_number = latest_block_number - 1
      block_hash = block_hash()
      block_quantity = integer_to_quantity(block_number)

      miner_hash = address_hash()
      miner_hash_data = to_string(miner_hash)

      new_block_hash = block_hash()

      refute block_hash == new_block_hash

      EthereumJSONRPC.Mox
      |> expect(:json_rpc, fn %{method: "eth_getBlockByNumber", params: ["latest", false]}, _options ->
        {:ok, %{"number" => latest_block_quantity}}
      end)
      |> expect(:json_rpc, fn [
                                %{
                                  id: id,
                                  jsonrpc: "2.0",
                                  method: "eth_getBlockByNumber",
                                  params: [^block_quantity, true]
                                }
                              ],
                              _options ->
        {:ok,
         [
           %{
             id: id,
             jsonrpc: "2.0",
             result: %{
               "hash" => to_string(block_hash),
               "number" => block_quantity,
               "difficulty" => "0x0",
               "gasLimit" => "0x0",
               "gasUsed" => "0x0",
               "extraData" => "0x0",
               "logsBloom" => "0x0",
               "miner" => miner_hash_data,
               "parentHash" =>
                 block_hash()
                 |> to_string(),
               "receiptsRoot" => "0x0",
               "size" => "0x0",
               "sha3Uncles" => "0x0",
               "stateRoot" => "0x0",
               "timestamp" => "0x0",
               "totalDifficulty" => "0x0",
               "transactions" => [],
               "transactionsRoot" => "0x0",
               "uncles" => []
             }
           }
         ]}
      end)
      |> expect(:json_rpc, fn [%{method: "trace_block", params: [^block_quantity]}], _options ->
        {:error, :boom}
      end)

      assert count(Chain.Block) == 0

      parent = self()

      pid =
        spawn_link(fn ->
          receive do
            {:"$gen_call", from, {:buffer, block_numbers}} ->
              GenServer.reply(from, :ok)
              send(parent, {:block_numbers, block_numbers})
          end
        end)

      Process.register(pid, BlockReward)

      assert %{first_block_number: ^block_number, missing_block_count: 1, shrunk: false} =
               Fetcher.task(%Fetcher{
                 blocks_batch_size: 1,
                 block_fetcher: %Block.Fetcher{
                   callback_module: Fetcher,
                   json_rpc_named_arguments: json_rpc_named_arguments
                 }
               })

      assert count(Chain.Block) == 1
      assert count(Reward) == 0

      assert_receive {:block_numbers, [block_number]}, 5_000
    end
  end

  defp count(schema) do
    Repo.one!(select(schema, fragment("COUNT(*)")))
  end
end
