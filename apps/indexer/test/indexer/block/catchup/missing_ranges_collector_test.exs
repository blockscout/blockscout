defmodule Indexer.Block.Catchup.MissingRangesCollectorTest do
  use Explorer.DataCase, async: false

  import Mox

  alias Explorer.Utility.MissingBlockRange
  alias Indexer.Block.Catchup.MissingRangesCollector

  setup :set_mox_global

  describe "default_init" do
    setup do
      initial_env = Application.get_all_env(:indexer)
      on_exit(fn -> Application.put_all_env([{:indexer, initial_env}]) end)
    end

    test "empty envs" do
      stub(EthereumJSONRPC.Mox, :json_rpc, fn [%{id: id, method: "eth_getBlockByNumber", params: ["latest", false]}],
                                              _options ->
        block_response(id, 1_000_000)
      end)

      insert(:block, number: 1_000_000)
      insert(:block, number: 500_123)
      MissingRangesCollector.start_link([])
      Process.sleep(1500)

      assert [999_999..999_900//-1] = batch = MissingBlockRange.get_latest_batch(100)
      MissingBlockRange.clear_batch(batch)
      assert [999_899..999_800//-1] = batch = MissingBlockRange.get_latest_batch(100)
      MissingBlockRange.clear_batch(batch)
      assert [999_799..999_700//-1] = batch = MissingBlockRange.get_latest_batch(100)
      MissingBlockRange.clear_batch(batch)

      stub(EthereumJSONRPC.Mox, :json_rpc, fn [%{id: id, method: "eth_getBlockByNumber", params: ["latest", false]}],
                                              _options ->
        block_response(id, 1_000_200)
      end)

      insert(:block, number: 1_000_200)
      Process.sleep(1000)

      assert [1_000_199..1_000_100//-1] = batch = MissingBlockRange.get_latest_batch(100)
      MissingBlockRange.clear_batch(batch)
      assert [1_000_099..1_000_001//-1, 999_699..999_699//-1] = batch = MissingBlockRange.get_latest_batch(100)
      MissingBlockRange.clear_batch(batch)
      assert [999_698..999_599//-1] = MissingBlockRange.get_latest_batch(100)
    end
  end

  describe "ranges_init" do
    setup do
      initial_env = Application.get_all_env(:indexer)
      on_exit(fn -> Application.put_all_env([{:indexer, initial_env}]) end)
    end

    test "infinite range" do
      stub(EthereumJSONRPC.Mox, :json_rpc, fn [%{id: id, method: "eth_getBlockByNumber", params: ["latest", false]}],
                                              _options ->
        block_response(id, 200)
      end)

      Application.put_env(:indexer, :block_ranges, "1..5,3..5,2qw1..12,10..11a,,asd..qwe,10..latest")

      insert(:block, number: 200)

      MissingRangesCollector.start_link([])
      Process.sleep(500)

      assert [199..100//-1] = batch = MissingBlockRange.get_latest_batch(100)
      MissingBlockRange.clear_batch(batch)
      assert [99..10//-1, 5..1//-1] = MissingBlockRange.get_latest_batch(100)
    end

    test "finite range" do
      Application.put_env(:indexer, :block_ranges, "10..20,5..15,18..25,35..40,30..50,150..200")

      insert(:block, number: 200_000)

      MissingRangesCollector.start_link([])
      Process.sleep(500)

      assert [200..150//-1, 50..30//-1, 25..5//-1] = batch = MissingBlockRange.get_latest_batch(100)
      MissingBlockRange.clear_batch(batch)
      assert [] = MissingBlockRange.get_latest_batch()
    end

    test "finite range with existing blocks" do
      Application.put_env(:indexer, :block_ranges, "10..20,5..15,18..25,35..40,30..50,150..200")

      insert(:block, number: 200_000)
      insert(:block, number: 175)
      insert(:block, number: 33)

      MissingRangesCollector.start_link([])
      Process.sleep(500)

      assert [200..176//-1, 174..150//-1, 50..34//-1, 32..30//-1, 25..5//-1] =
               batch = MissingBlockRange.get_latest_batch(91)

      MissingBlockRange.clear_batch(batch)
      assert [] = MissingBlockRange.get_latest_batch()
    end
  end

  test "parse_block_ranges/1" do
    assert MissingRangesCollector.parse_block_ranges("1..5,3..5,2qw1..12,10..11a,,asd..qwe,10..latest") ==
             {:infinite_ranges, [1..5], 9}

    assert MissingRangesCollector.parse_block_ranges("latest..123,,fvdskvjglav!@#$%^&,2..1") == :no_ranges

    assert MissingRangesCollector.parse_block_ranges("10..20,5..15,18..25,35..40,30..50,100..latest,150..200") ==
             {:infinite_ranges, [5..25, 30..50], 99}

    assert MissingRangesCollector.parse_block_ranges("10..20,5..15,18..25,35..40,30..50,150..200") ==
             {:finite_ranges, [5..25, 30..50, 150..200]}
  end

  defp block_response(id, block_number) do
    {:ok,
     [
       %{
         id: id,
         result: %{
           "difficulty" => "0x0",
           "gasLimit" => "0x0",
           "gasUsed" => "0x0",
           "hash" => "0x29c850324e357f3c0c836d79860c5af55f7b651e5d7ee253c1af1b14908af49c",
           "extraData" => "0x0",
           "logsBloom" => "0x0",
           "miner" => "0x0",
           "number" => block_number,
           "parentHash" => "0x0",
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
  end
end
