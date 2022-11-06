defmodule Indexer.Fetcher.BlockRewardTest do
  # MUST be `async: false` so that {:shared, pid} is set for connection to allow CoinBalanceFetcher's self-send to have
  # connection allowed immediately.
  use EthereumJSONRPC.Case, async: false
  use Explorer.DataCase

  import EthereumJSONRPC, only: [integer_to_quantity: 1]
  import Mox

  alias Explorer.Chain
  alias Explorer.Chain.{Block, Hash, Wei}
  alias Indexer.BufferedTask
  alias Indexer.Fetcher.BlockReward

  @moduletag :capture_log

  # MUST use global mode because we aren't guaranteed to get `start_supervised`'s pid back fast enough to `allow` it to
  # use expectations and stubs from test's pid.
  setup :set_mox_global

  setup :verify_on_exit!

  setup do
    start_supervised!({Task.Supervisor, name: Indexer.TaskSupervisor})

    # Need to always mock to allow consensus switches to happen on demand and protect from them happening when we don't
    # want them to.
    %{
      json_rpc_named_arguments: [
        transport: EthereumJSONRPC.Mox,
        transport_options: [],
        # Which one does not matter, so pick one
        variant: EthereumJSONRPC.Nethermind
      ]
    }
  end

  describe "init/3" do
    test "without blocks" do
      assert [] = BlockReward.init([], &[&1 | &2], nil)
    end

    test "with consensus block without reward" do
      %Block{number: block_number} = insert(:block)

      assert [^block_number] = BlockReward.init([], &[&1 | &2], nil)
    end

    test "with consensus block with reward" do
      block = insert(:block)
      insert(:reward, address_hash: block.miner_hash, block_hash: block.hash)

      assert [] = BlockReward.init([], &[&1 | &2], nil)
    end

    test "with non-consensus block" do
      insert(:block, consensus: false)

      assert [] = BlockReward.init([], &[&1 | &2], nil)
    end
  end

  describe "async_fetch/1" do
    setup %{json_rpc_named_arguments: json_rpc_named_arguments} do
      BlockReward.Supervisor.Case.start_supervised!(json_rpc_named_arguments: json_rpc_named_arguments)

      block = insert(:block)

      %{block: block}
    end

    test "with consensus block without reward", %{
      block: %Block{
        hash: block_hash,
        number: block_number,
        miner_hash: %Hash{bytes: miner_hash_bytes} = miner_hash,
        consensus: true
      }
    } do
      block_quantity = integer_to_quantity(block_number)

      expect(EthereumJSONRPC.Mox, :json_rpc, fn [
                                                  %{
                                                    id: id,
                                                    jsonrpc: "2.0",
                                                    method: "trace_block",
                                                    params: [^block_quantity]
                                                  }
                                                ],
                                                _ ->
        {
          :ok,
          [
            %{
              id: id,
              jsonrpc: "2.0",
              result: [
                %{
                  "action" => %{
                    "author" => to_string(miner_hash),
                    "rewardType" => "external",
                    "value" => "0x0"
                  },
                  # ... but, switches to non-consensus by the time `trace_block` is called
                  "blockHash" => to_string(block_hash),
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

      _res = eth_block_number_fake_response(block_quantity)

      assert count(Chain.Block.Reward) == 0

      parent = self()

      pid =
        spawn_link(fn ->
          receive do
            {:"$gen_call", from, {:buffer, balance_fields}} ->
              GenServer.reply(from, :ok)
              send(parent, {:balance_fields, balance_fields})
          end
        end)

      Process.register(pid, Indexer.Fetcher.CoinBalance)

      assert :ok = BlockReward.async_fetch([block_number])

      wait_for_tasks(BlockReward)

      assert count(Chain.Block.Reward) == 1
      assert_receive {:balance_fields, [{^miner_hash_bytes, ^block_number}]}, 500
    end

    test "with consensus block with reward", %{
      block: %Block{
        hash: block_hash,
        number: block_number,
        miner_hash: %Hash{bytes: miner_hash_bytes} = miner_hash,
        consensus: true
      }
    } do
      insert(:reward, block_hash: block_hash, address_hash: miner_hash)

      block_quantity = integer_to_quantity(block_number)

      expect(EthereumJSONRPC.Mox, :json_rpc, fn [
                                                  %{
                                                    id: id,
                                                    jsonrpc: "2.0",
                                                    method: "trace_block",
                                                    params: [^block_quantity]
                                                  }
                                                ],
                                                _ ->
        {
          :ok,
          [
            %{
              id: id,
              jsonrpc: "2.0",
              result: [
                %{
                  "action" => %{
                    "author" => to_string(miner_hash),
                    "rewardType" => "external",
                    "value" => "0x0"
                  },
                  # ... but, switches to non-consensus by the time `trace_block` is called
                  "blockHash" => to_string(block_hash),
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

      _res = eth_block_number_fake_response(block_quantity)

      parent = self()

      pid =
        spawn_link(fn ->
          receive do
            {:"$gen_call", from, {:buffer, balance_fields}} ->
              GenServer.reply(from, :ok)
              send(parent, {:balance_fields, balance_fields})
          end
        end)

      Process.register(pid, Indexer.Fetcher.CoinBalance)

      assert :ok = BlockReward.async_fetch([block_number])

      wait_for_tasks(BlockReward)

      assert count(Chain.Block.Reward) == 1
      assert_receive {:balance_fields, [{^miner_hash_bytes, ^block_number}]}, 500
    end

    test "with consensus block does not import if fetch beneficiaries returns a different block hash for block number",
         %{block: %Block{hash: block_hash, number: block_number, consensus: true, miner_hash: miner_hash}} do
      block_quantity = integer_to_quantity(block_number)
      new_block_hash = block_hash()

      refute block_hash == new_block_hash

      expect(EthereumJSONRPC.Mox, :json_rpc, fn [
                                                  %{
                                                    id: id,
                                                    jsonrpc: "2.0",
                                                    method: "trace_block",
                                                    params: [^block_quantity]
                                                  }
                                                ],
                                                _ ->
        {
          :ok,
          [
            %{
              id: id,
              jsonrpc: "2.0",
              result: [
                %{
                  "action" => %{
                    "author" => to_string(miner_hash),
                    "rewardType" => "external",
                    "value" => "0x0"
                  },
                  # ... but, switches to non-consensus by the time `trace_block` is called
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

      assert :ok = BlockReward.async_fetch([block_number])

      wait_for_tasks(BlockReward)

      assert count(Chain.Block.Reward) == 0
    end
  end

  describe "run/2" do
    setup do
      block = insert(:block)

      %{block: block}
    end

    test "with consensus block without reward", %{
      block: %Block{
        hash: block_hash,
        number: block_number,
        miner_hash: %Hash{bytes: miner_hash_bytes} = miner_hash,
        consensus: true
      },
      json_rpc_named_arguments: json_rpc_named_arguments
    } do
      block_quantity = integer_to_quantity(block_number)

      expect(EthereumJSONRPC.Mox, :json_rpc, fn [
                                                  %{
                                                    id: id,
                                                    jsonrpc: "2.0",
                                                    method: "trace_block",
                                                    params: [^block_quantity]
                                                  }
                                                ],
                                                _ ->
        {
          :ok,
          [
            %{
              id: id,
              jsonrpc: "2.0",
              result: [
                %{
                  "action" => %{
                    "author" => to_string(miner_hash),
                    "rewardType" => "external",
                    "value" => "0x0"
                  },
                  # ... but, switches to non-consensus by the time `trace_block` is called
                  "blockHash" => to_string(block_hash),
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

      _res = eth_block_number_fake_response(block_quantity)

      assert count(Chain.Block.Reward) == 0
      assert count(Chain.Address.CoinBalance) == 0

      parent = self()

      pid =
        spawn_link(fn ->
          receive do
            {:"$gen_call", from, {:buffer, balance_fields}} ->
              GenServer.reply(from, :ok)
              send(parent, {:balance_fields, balance_fields})
          end
        end)

      Process.register(pid, Indexer.Fetcher.CoinBalance)

      assert :ok = BlockReward.run([block_number], json_rpc_named_arguments)

      assert count(Chain.Block.Reward) == 1
      assert count(Chain.Address.CoinBalance) == 1
      assert_receive {:balance_fields, [{^miner_hash_bytes, ^block_number}]}, 500
    end

    test "with consensus block without reward with new address adds rewards for all addresses", %{
      block: %Block{
        hash: block_hash,
        number: block_number,
        miner_hash: %Hash{bytes: miner_hash_bytes} = miner_hash,
        consensus: true
      },
      json_rpc_named_arguments: json_rpc_named_arguments
    } do
      block_quantity = integer_to_quantity(block_number)
      %Hash{bytes: new_address_hash_bytes} = new_address_hash = address_hash()

      expect(EthereumJSONRPC.Mox, :json_rpc, fn [
                                                  %{
                                                    id: id,
                                                    jsonrpc: "2.0",
                                                    method: "trace_block",
                                                    params: [^block_quantity]
                                                  }
                                                ],
                                                _ ->
        {
          :ok,
          [
            %{
              id: id,
              jsonrpc: "2.0",
              result: [
                %{
                  "action" => %{
                    "author" => to_string(miner_hash),
                    "rewardType" => "external",
                    "value" => "0x1"
                  },
                  # ... but, switches to non-consensus by the time `trace_block` is called
                  "blockHash" => to_string(block_hash),
                  "blockNumber" => block_number,
                  "result" => nil,
                  "subtraces" => 0,
                  "traceAddress" => [],
                  "transactionHash" => nil,
                  "transactionPosition" => nil,
                  "type" => "reward"
                },
                %{
                  "action" => %{
                    "author" => to_string(new_address_hash),
                    "rewardType" => "external",
                    "value" => "0x2"
                  },
                  "blockHash" => to_string(block_hash),
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

      _res = eth_block_number_fake_response(block_quantity)

      assert count(Chain.Block.Reward) == 0
      assert count(Chain.Address.CoinBalance) == 0

      parent = self()

      pid =
        spawn_link(fn ->
          receive do
            {:"$gen_call", from, {:buffer, balance_fields}} ->
              GenServer.reply(from, :ok)
              send(parent, {:balance_fields, balance_fields})
          end
        end)

      Process.register(pid, Indexer.Fetcher.CoinBalance)

      assert :ok = BlockReward.run([block_number], json_rpc_named_arguments)

      assert count(Chain.Block.Reward) == 2
      assert count(Chain.Address.CoinBalance) == 2

      assert_receive {:balance_fields, balance_fields}, 500
      assert {miner_hash_bytes, block_number} in balance_fields
      assert {new_address_hash_bytes, block_number} in balance_fields
    end

    test "with consensus block with reward", %{
      block: %Block{
        hash: block_hash,
        number: block_number,
        miner_hash: %Hash{bytes: miner_hash_bytes} = miner_hash,
        consensus: true
      },
      json_rpc_named_arguments: json_rpc_named_arguments
    } do
      insert(:reward, block_hash: block_hash, address_hash: miner_hash, reward: 0)
      insert(:unfetched_balance, address_hash: miner_hash, block_number: block_number)

      block_quantity = integer_to_quantity(block_number)

      expect(EthereumJSONRPC.Mox, :json_rpc, fn [
                                                  %{
                                                    id: id,
                                                    jsonrpc: "2.0",
                                                    method: "trace_block",
                                                    params: [^block_quantity]
                                                  }
                                                ],
                                                _ ->
        {
          :ok,
          [
            %{
              id: id,
              jsonrpc: "2.0",
              result: [
                %{
                  "action" => %{
                    "author" => to_string(miner_hash),
                    "rewardType" => "external",
                    "value" => "0x1"
                  },
                  # ... but, switches to non-consensus by the time `trace_block` is called
                  "blockHash" => to_string(block_hash),
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

      _res = eth_block_number_fake_response(block_quantity)

      assert count(Chain.Block.Reward) == 1
      assert count(Chain.Address.CoinBalance) == 1

      value = Decimal.new(0)

      assert [%Chain.Block.Reward{reward: %Wei{value: ^value}}] = Repo.all(Chain.Block.Reward)

      parent = self()

      pid =
        spawn_link(fn ->
          receive do
            {:"$gen_call", from, {:buffer, balance_fields}} ->
              GenServer.reply(from, :ok)
              send(parent, {:balance_fields, balance_fields})
          end
        end)

      Process.register(pid, Indexer.Fetcher.CoinBalance)

      assert :ok = BlockReward.run([block_number], json_rpc_named_arguments)

      assert count(Chain.Block.Reward) == 1
      assert count(Chain.Address.CoinBalance) == 1

      value = Decimal.new(1)

      assert [%Chain.Block.Reward{reward: %Wei{value: ^value}}] = Repo.all(Chain.Block.Reward)
      assert_receive {:balance_fields, [{^miner_hash_bytes, ^block_number}]}, 500
    end

    test "with consensus block does not import if fetch beneficiaries returns a different block hash for block number",
         %{
           block: %Block{hash: block_hash, number: block_number, consensus: true, miner_hash: miner_hash},
           json_rpc_named_arguments: json_rpc_named_arguments
         } do
      block_quantity = integer_to_quantity(block_number)
      new_block_hash = block_hash()

      refute block_hash == new_block_hash

      expect(EthereumJSONRPC.Mox, :json_rpc, fn [
                                                  %{
                                                    id: id,
                                                    jsonrpc: "2.0",
                                                    method: "trace_block",
                                                    params: [^block_quantity]
                                                  }
                                                ],
                                                _ ->
        {
          :ok,
          [
            %{
              id: id,
              jsonrpc: "2.0",
              result: [
                %{
                  "action" => %{
                    "author" => to_string(miner_hash),
                    "rewardType" => "external",
                    "value" => "0x0"
                  },
                  # ... but, switches to non-consensus by the time `trace_block` is called
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

      assert :ok = BlockReward.run([block_number], json_rpc_named_arguments)

      assert count(Chain.Block.Reward) == 0
      assert count(Chain.Address.CoinBalance) == 0
    end

    test "with mix of beneficiaries_params and errors, imports beneficiaries_params and retries errors", %{
      block: %Block{
        hash: block_hash,
        number: block_number,
        miner_hash: %Hash{bytes: miner_hash_bytes} = miner_hash,
        consensus: true
      },
      json_rpc_named_arguments: json_rpc_named_arguments
    } do
      block_quantity = integer_to_quantity(block_number)
      %Block{number: error_block_number} = insert(:block)

      error_block_quantity = integer_to_quantity(error_block_number)

      EthereumJSONRPC.Mox
      |> expect(:json_rpc, fn [_, _] = requests, _ ->
        {
          :ok,
          Enum.map(requests, fn
            %{
              id: id,
              jsonrpc: "2.0",
              method: "trace_block",
              params: [^block_quantity]
            } ->
              %{
                id: id,
                jsonrpc: "2.0",
                result: [
                  %{
                    "action" => %{
                      "author" => to_string(miner_hash),
                      "rewardType" => "external",
                      "value" => "0x1"
                    },
                    # ... but, switches to non-consensus by the time `trace_block` is called
                    "blockHash" => to_string(block_hash),
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

            %{id: id, jsonrpc: "2.0", method: "trace_block", params: [^error_block_quantity]} ->
              %{id: id, jsonrpc: "2.0", result: nil}
          end)
        }
      end)

      _res = eth_block_number_fake_response(block_quantity)

      assert count(Chain.Block.Reward) == 0
      assert count(Chain.Address.CoinBalance) == 0

      parent = self()

      pid =
        spawn_link(fn ->
          receive do
            {:"$gen_call", from, {:buffer, balance_fields}} ->
              GenServer.reply(from, :ok)
              send(parent, {:balance_fields, balance_fields})
          end
        end)

      Process.register(pid, Indexer.Fetcher.CoinBalance)

      assert {:retry, [^error_block_number]} =
               BlockReward.run([block_number, error_block_number], json_rpc_named_arguments)

      assert count(Chain.Block.Reward) == 1
      assert count(Chain.Address.CoinBalance) == 1

      assert_receive {:balance_fields, balance_fields}, 500
      assert {miner_hash_bytes, block_number} in balance_fields
    end
  end

  defp count(schema) do
    Repo.one!(select(schema, fragment("COUNT(*)")))
  end

  defp wait_for_tasks(buffered_task) do
    wait_until(:timer.seconds(10), fn ->
      counts = BufferedTask.debug_count(buffered_task)
      counts.buffer == 0 and counts.tasks == 0
    end)
  end

  defp wait_until(timeout, producer) do
    parent = self()
    ref = make_ref()

    spawn(fn -> do_wait_until(parent, ref, producer) end)

    receive do
      {^ref, :ok} -> :ok
    after
      timeout -> exit(:timeout)
    end
  end

  defp do_wait_until(parent, ref, producer) do
    if producer.() do
      send(parent, {ref, :ok})
    else
      :timer.sleep(100)
      do_wait_until(parent, ref, producer)
    end
  end

  defp eth_block_number_fake_response(block_quantity) do
    %{
      id: 0,
      jsonrpc: "2.0",
      result: %{
        "author" => "0x0000000000000000000000000000000000000000",
        "difficulty" => "0x20000",
        "extraData" => "0x",
        "gasLimit" => "0x663be0",
        "gasUsed" => "0x0",
        "hash" => "0x5b28c1bfd3a15230c9a46b399cd0f9a6920d432e85381cc6a140b06e8410112f",
        "logsBloom" =>
          "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
        "miner" => "0x0000000000000000000000000000000000000000",
        "number" => block_quantity,
        "parentHash" => "0x0000000000000000000000000000000000000000000000000000000000000000",
        "receiptsRoot" => "0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421",
        "sealFields" => [
          "0x80",
          "0xb8410000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"
        ],
        "sha3Uncles" => "0x1dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347",
        "signature" =>
          "0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
        "size" => "0x215",
        "stateRoot" => "0xfad4af258fd11939fae0c6c6eec9d340b1caac0b0196fd9a1bc3f489c5bf00b3",
        "step" => "0",
        "timestamp" => "0x0",
        "totalDifficulty" => "0x20000",
        "transactions" => [],
        "transactionsRoot" => "0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421",
        "uncles" => []
      }
    }
  end
end
