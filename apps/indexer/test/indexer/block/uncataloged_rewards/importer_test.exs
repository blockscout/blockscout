defmodule Indexer.Block.UncatalogedRewards.ImporterTest do
  use EthereumJSONRPC.Case, async: false
  use Explorer.DataCase

  import Mox

  alias Explorer.Chain.Wei
  alias Explorer.Chain.Block.Reward
  alias Indexer.Block.UncatalogedRewards.Importer

  describe "fetch_and_import_rewards/1" do
    test "return `{:ok, []}` when receiving an empty list" do
      assert Importer.fetch_and_import_rewards([]) == {:ok, []}
    end

    @tag :no_geth
    test "return `{:ok, [transactions executed]}`" do
      address = insert(:address)
      block = insert(:block, number: 1234, miner: address)

      expect(EthereumJSONRPC.Mox, :json_rpc, fn [%{id: id, method: "trace_block", params: _params}], _options ->
        {:ok,
         [
           %{
             id: id,
             result: [
               %{
                 "action" => %{
                   "author" => to_string(address.hash),
                   "rewardType" => "external",
                   "value" => "0xde0b6b3a7640000"
                 },
                 "blockHash" => to_string(block.hash),
                 "blockNumber" => 1234,
                 "result" => nil,
                 "subtraces" => 0,
                 "traceAddress" => [],
                 "transactionHash" => nil,
                 "transactionPosition" => nil,
                 "type" => "reward"
               }
             ]
           }
         ]}
      end)

      expected =
        {:ok,
         [
           ok: %{
             "insert_0" => %Reward{
               address_hash: address.hash,
               block_hash: block.hash,
               address_type: :validator
             }
           }
         ]}

      result = Importer.fetch_and_import_rewards([block])
      assert result = expected
    end

    @tag :no_geth
    test "replaces reward on conflict" do
      miner = insert(:address)
      block = insert(:block, miner: miner)
      block_hash = block.hash
      address_type = :validator
      insert(:reward, block_hash: block_hash, address_hash: miner.hash, address_type: address_type, reward: 1)
      value = "0x2"

      expect(EthereumJSONRPC.Mox, :json_rpc, fn [%{id: id, method: "trace_block"}], _options ->
        {:ok,
         [
           %{
             id: id,
             result: [
               %{
                 "action" => %{
                   "author" => to_string(miner),
                   "rewardType" => "external",
                   "value" => value
                 },
                 "blockHash" => to_string(block_hash),
                 "blockNumber" => block.number,
                 "result" => nil,
                 "subtraces" => 0,
                 "traceAddress" => [],
                 "transactionHash" => nil,
                 "transactionPosition" => nil,
                 "type" => "reward"
               }
             ]
           }
         ]}
      end)

      {:ok, reward} = Wei.cast(value)

      assert {:ok,
              [ok: %{"insert_0" => %Reward{block_hash: ^block_hash, address_type: ^address_type, reward: ^reward}}]} =
               Importer.fetch_and_import_rewards([block])
    end
  end
end
