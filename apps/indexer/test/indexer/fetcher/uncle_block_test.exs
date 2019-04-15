defmodule Indexer.Fetcher.UncleBlockTest do
  # MUST be `async: false` so that {:shared, pid} is set for connection to allow CoinBalanceFetcher's self-send to have
  # connection allowed immediately.
  use EthereumJSONRPC.Case, async: false
  use Explorer.DataCase

  alias Explorer.Chain
  alias Indexer.Block
  alias Indexer.Fetcher.UncleBlock

  import Mox

  @moduletag :capture_log

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

  describe "child_spec/1" do
    test "raises ArgumentError is `json_rpc_named_arguments is not provided" do
      assert_raise ArgumentError,
                   ":json_rpc_named_arguments must be provided to `Elixir.Indexer.Fetcher.UncleBlock.child_spec " <>
                     "to allow for json_rpc calls when running.",
                   fn ->
                     start_supervised({UncleBlock, [[], []]})
                   end
    end
  end

  describe "init/1" do
    test "fetched unfetched uncle hashes", %{json_rpc_named_arguments: json_rpc_named_arguments} do
      assert %Chain.Block.SecondDegreeRelation{nephew_hash: nephew_hash, uncle_hash: uncle_hash, uncle: nil} =
               :block_second_degree_relation
               |> insert()
               |> Repo.preload([:nephew, :uncle])

      uncle_hash_data = to_string(uncle_hash)
      uncle_uncle_hash_data = to_string(block_hash())

      EthereumJSONRPC.Mox
      |> expect(:json_rpc, fn [%{id: id, method: "eth_getBlockByHash", params: [^uncle_hash_data, true]}], _ ->
        number_quantity = "0x0"

        {:ok,
         [
           %{
             id: id,
             result: %{
               "author" => "0xe2ac1c6843a33f81ae4935e5ef1277a392990381",
               "difficulty" => "0xfffffffffffffffffffffffffffffffe",
               "extraData" => "0xd583010a068650617269747986312e32362e32826c69",
               "gasLimit" => "0x7a1200",
               "gasUsed" => "0x0",
               "hash" => uncle_hash_data,
               "logsBloom" => "0x",
               "miner" => "0xe2ac1c6843a33f81ae4935e5ef1277a392990381",
               "number" => number_quantity,
               "parentHash" => "0x006edcaa1e6fde822908783bc4ef1ad3675532d542fce53537557391cfe34c3c",
               "size" => "0x243",
               "receiptsRoot" => "0x0",
               "sha3Uncles" => "0x0",
               "stateRoot" => "0x0",
               "timestamp" => "0x5b437f41",
               "totalDifficulty" => "0x342337ffffffffffffffffffffffffed8d29bb",
               "transactions" => [
                 %{
                   "blockHash" => uncle_hash_data,
                   "blockNumber" => number_quantity,
                   "chainId" => "0x4d",
                   "condition" => nil,
                   "creates" => "0xffc87239eb0267bc3ca2cd51d12fbf278e02ccb4",
                   "from" => "0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca",
                   "gas" => "0x47b760",
                   "gasPrice" => "0x174876e800",
                   "hash" => "0x3a3eb134e6792ce9403ea4188e5e79693de9e4c94e499db132be086400da79e6",
                   "input" => "0x",
                   "nonce" => "0x0",
                   "r" => "0xad3733df250c87556335ffe46c23e34dbaffde93097ef92f52c88632a40f0c75",
                   "s" => "0x72caddc0371451a58de2ca6ab64e0f586ccdb9465ff54e1c82564940e89291e3",
                   "standardV" => "0x0",
                   "to" => nil,
                   "transactionIndex" => "0x0",
                   "v" => "0xbd",
                   "value" => "0x0"
                 }
               ],
               "transactionsRoot" => "0x0",
               "uncles" => [uncle_uncle_hash_data]
             }
           }
         ]}
      end)

      UncleBlock.Supervisor.Case.start_supervised!(
        block_fetcher: %Block.Fetcher{json_rpc_named_arguments: json_rpc_named_arguments}
      )

      wait(fn ->
        Repo.one!(
          from(bsdr in Chain.Block.SecondDegreeRelation,
            where: bsdr.nephew_hash == ^nephew_hash and not is_nil(bsdr.uncle_fetched_at)
          )
        )
      end)

      refute is_nil(Repo.get(Chain.Block, uncle_hash))
      assert Repo.aggregate(Chain.Transaction.Fork, :count, :hash) == 1
    end
  end

  defp wait(producer) do
    producer.()
  rescue
    Ecto.NoResultsError ->
      Process.sleep(100)
      wait(producer)
  end
end
