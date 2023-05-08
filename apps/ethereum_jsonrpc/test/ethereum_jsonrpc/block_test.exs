defmodule EthereumJSONRPC.BlockTest do
  use ExUnit.Case, async: true

  doctest EthereumJSONRPC.Block

  alias EthereumJSONRPC.Block

  describe "elixir_to_params/1" do
    test "sets totalDifficulty to nil if it's empty" do
      result =
        Block.elixir_to_params(%{
          "difficulty" => 17_561_410_778,
          "extraData" => "0x476574682f4c5649562f76312e302e302f6c696e75782f676f312e342e32",
          "gasLimit" => 5000,
          "gasUsed" => 0,
          "hash" => "0x4d9423080290a650eaf6db19c87c76dff83d1b4ab64aefe6e5c5aa2d1f4b6623",
          "logsBloom" =>
            "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
          "miner" => "0xbb7b8287f3f0a933474a79eae42cbca977791171",
          "mixHash" => "0xbbb93d610b2b0296a59f18474ac3d6086a9902aa7ca4b9a306692f7c3d496fdf",
          "nonce" => 5_539_500_215_739_777_653,
          "number" => 59,
          "parentHash" => "0xcd5b5c4cecd7f18a13fe974255badffd58e737dc67596d56bc01f063dd282e9e",
          "receiptsRoot" => "0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421",
          "sha3Uncles" => "0x1dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347",
          "size" => 542,
          "stateRoot" => "0x6fd0a5d82ca77d9f38c3ebbde11b11d304a5fcf3854f291df64395ab38ed43ba",
          "timestamp" => Timex.parse!("2015-07-30T15:32:07Z", "{ISO:Extended:Z}"),
          "totalDifficulty" => nil,
          "transactions" => [],
          "transactionsRoot" => "0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421",
          "uncles" => []
        })

      assert result == %{
               difficulty: 17_561_410_778,
               extra_data: "0x476574682f4c5649562f76312e302e302f6c696e75782f676f312e342e32",
               gas_limit: 5000,
               gas_used: 0,
               hash: "0x4d9423080290a650eaf6db19c87c76dff83d1b4ab64aefe6e5c5aa2d1f4b6623",
               logs_bloom:
                 "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
               mix_hash: "0xbbb93d610b2b0296a59f18474ac3d6086a9902aa7ca4b9a306692f7c3d496fdf",
               miner_hash: "0xbb7b8287f3f0a933474a79eae42cbca977791171",
               nonce: 5_539_500_215_739_777_653,
               number: 59,
               parent_hash: "0xcd5b5c4cecd7f18a13fe974255badffd58e737dc67596d56bc01f063dd282e9e",
               receipts_root: "0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421",
               sha3_uncles: "0x1dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347",
               size: 542,
               state_root: "0x6fd0a5d82ca77d9f38c3ebbde11b11d304a5fcf3854f291df64395ab38ed43ba",
               timestamp: Timex.parse!("2015-07-30T15:32:07Z", "{ISO:Extended:Z}"),
               total_difficulty: nil,
               transactions_root: "0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421",
               uncles: [],
               withdrawals_root: "0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421"
             }
    end
  end

  describe "elixir_to_transactions/1" do
    test "converts to empty list if there is not transaction key" do
      assert Block.elixir_to_transactions(%{}) == []
    end
  end

  describe "elixir_to_withdrawals/1" do
    test "converts to empty list if there is no withdrawals key" do
      assert Block.elixir_to_withdrawals(%{}) == []
    end

    test "converts to empty list if withdrawals is nil" do
      assert Block.elixir_to_withdrawals(%{withdrawals: nil}) == []
    end
  end
end
