# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Indexer.Fetcher.UncleBlockTest do
  # MUST be `async: false` so that {:shared, pid} is set for connection to allow CoinBalanceFetcher's self-send to have
  # connection allowed immediately.
  use EthereumJSONRPC.Case, async: false
  use Explorer.DataCase

  import EthereumJSONRPC, only: [integer_to_quantity: 1]

  alias EthereumJSONRPC.Blocks
  alias Explorer.Chain
  alias Explorer.Chain.Hash
  alias Explorer.Utility.MissingBlockRange
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
        variant: EthereumJSONRPC.Nethermind
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
      assert %Chain.Block.SecondDegreeRelation{
               nephew_hash: nephew_hash,
               uncle_hash: uncle_hash,
               index: index,
               uncle: nil
             } =
               :block_second_degree_relation
               |> insert()
               |> Repo.preload([:nephew, :uncle])

      nephew_hash_data = to_string(nephew_hash)
      uncle_hash_data = to_string(uncle_hash)
      uncle_uncle_hash_data = to_string(block_hash())
      index_data = integer_to_quantity(index)
      transaction_hash = "0x3a3eb134e6792ce9403ea4188e5e79693de9e4c94e499db132be086400da79e6"

      EthereumJSONRPC.Mox
      |> expect(:json_rpc, fn [
                                %{
                                  id: id,
                                  method: "eth_getUncleByBlockHashAndIndex",
                                  params: [^nephew_hash_data, ^index_data]
                                }
                              ],
                              _ ->
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
                   "hash" => transaction_hash,
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
        block_fetcher: %Block.Fetcher{json_rpc_named_arguments: json_rpc_named_arguments, task_supervisor: nil}
      )

      wait(fn ->
        Repo.one!(
          from(bsdr in Chain.Block.SecondDegreeRelation,
            where: bsdr.nephew_hash == ^nephew_hash and not is_nil(bsdr.uncle_fetched_at)
          )
        )
      end)

      wait_for_results(fn ->
        Repo.one!(
          from(tf in Chain.Transaction.Fork,
            where: tf.hash == ^transaction_hash,
            select: tf.hash
          )
        )
      end)

      refute is_nil(Repo.get(Chain.Block, uncle_hash))
      assert Repo.aggregate(Chain.Transaction.Fork, :count, :hash) == 1
    end
  end

  describe "run/2" do
    test "retries failed request", %{json_rpc_named_arguments: json_rpc_named_arguments} do
      %Hash{bytes: block_hash_bytes} = block_hash()
      entries = [{block_hash_bytes, 0}]

      EthereumJSONRPC.Mox
      |> expect(:json_rpc, fn [
                                %{
                                  id: id,
                                  method: "eth_getUncleByBlockHashAndIndex"
                                }
                              ],
                              _ ->
        {:ok,
         [
           %{
             id: id,
             error: %{
               code: 404,
               data: %{index: 0, nephew_hash: "0xa0814f0478fe90c82852f812fd74c96df148654c326d2600d836e6908ebb62b4"},
               message: "Not Found"
             }
           }
         ]}
      end)

      assert {:retry, ^entries} =
               UncleBlock.run(entries, %Block.Fetcher{
                 json_rpc_named_arguments: json_rpc_named_arguments,
                 task_supervisor: nil
               })
    end

    test "retries only unique uncles on failed request", %{json_rpc_named_arguments: json_rpc_named_arguments} do
      %Hash{bytes: block_hash_bytes} = block_hash()
      entry = {block_hash_bytes, 0}
      entries = [entry, entry]

      EthereumJSONRPC.Mox
      |> expect(:json_rpc, fn [
                                %{
                                  id: id,
                                  method: "eth_getUncleByBlockHashAndIndex"
                                }
                              ],
                              _ ->
        {:ok,
         [
           %{
             id: id,
             error: %{
               code: 404,
               data: %{index: 0, nephew_hash: "0xa0814f0478fe90c82852f812fd74c96df148654c326d2600d836e6908ebb62b4"},
               message: "Not Found"
             }
           }
         ]}
      end)

      assert {:retry, [^entry]} =
               UncleBlock.run(entries, %Block.Fetcher{
                 json_rpc_named_arguments: json_rpc_named_arguments,
                 task_supervisor: nil
               })
    end
  end

  describe "run_blocks/2" do
    test "converts errors to entries for retry", %{json_rpc_named_arguments: json_rpc_named_arguments} do
      miner_hash =
        address_hash()
        |> to_string()

      block_number = 1

      index = 0

      hash = "0xa0814f0478fe90c82852f812fd74c96df148654c326d2600d836e6908ebb62b4"

      params = %Blocks{
        errors: [
          %{
            code: 404,
            data: %{index: index, nephew_hash: hash},
            message: "Not Found"
          }
        ],
        blocks_params: [%{miner_hash: miner_hash, number: block_number}]
      }

      assert {:retry, [{bin_hash, ^index}]} =
               UncleBlock.run_blocks(
                 params,
                 %Block.Fetcher{
                   json_rpc_named_arguments: json_rpc_named_arguments,
                   callback_module: Indexer.Block.Realtime.Fetcher,
                   task_supervisor: nil
                 },
                 []
               )

      assert Hash.Full.cast(bin_hash) == Hash.Full.cast(hash)
    end
  end

  describe "stored uncles" do
    test "a stored consensus block is not changed and its number is scheduled for refetch",
         %{json_rpc_named_arguments: json_rpc_named_arguments} do
      uncle = insert(:block, consensus: true)
      transaction = :transaction |> insert() |> with_block(uncle)
      %{nephew_hash: nephew_hash} = insert(:block_second_degree_relation, uncle_hash: uncle.hash)

      blocks = %Blocks{
        blocks_params: [%{hash: to_string(uncle.hash), number: uncle.number}],
        transactions_params: [%{block_hash: to_string(uncle.hash), hash: to_string(transaction.hash), index: 0}]
      }

      assert :ok = UncleBlock.run_blocks(blocks, block_fetcher(json_rpc_named_arguments), [{nephew_hash.bytes, 0}])

      assert %Chain.Block{consensus: true, refetch_needed: true} = Repo.get!(Chain.Block, uncle.hash)
      assert Repo.get!(Chain.Transaction, transaction.hash).block_hash == uncle.hash
      assert Repo.aggregate(Chain.Transaction.Fork, :count, :hash) == 0
      assert [%MissingBlockRange{from_number: number, to_number: number}] = Repo.all(MissingBlockRange)
      assert number == uncle.number
      assert %DateTime{} = fetched_relation!(nephew_hash, uncle.hash).uncle_fetched_at
    end

    test "a stored non-consensus block is not changed", %{json_rpc_named_arguments: json_rpc_named_arguments} do
      uncle = insert(:block, consensus: false)
      %{nephew_hash: nephew_hash} = insert(:block_second_degree_relation, uncle_hash: uncle.hash)

      blocks = %Blocks{blocks_params: [%{hash: to_string(uncle.hash), number: uncle.number}]}

      assert :ok = UncleBlock.run_blocks(blocks, block_fetcher(json_rpc_named_arguments), [{nephew_hash.bytes, 0}])

      assert %Chain.Block{consensus: false, refetch_needed: false, updated_at: updated_at} =
               Repo.get!(Chain.Block, uncle.hash)

      assert updated_at == uncle.updated_at
      assert Repo.all(MissingBlockRange) == []
      assert %DateTime{} = fetched_relation!(nephew_hash, uncle.hash).uncle_fetched_at
    end

    test "only the uncles that are not stored yet are imported",
         %{json_rpc_named_arguments: json_rpc_named_arguments} do
      stored_uncle = insert(:block, consensus: true)
      nephew = insert(:block)
      new_uncle_hash = block_hash()

      insert(:block_second_degree_relation, nephew: nephew, uncle_hash: stored_uncle.hash, index: 0)
      insert(:block_second_degree_relation, nephew: nephew, uncle_hash: new_uncle_hash, index: 1)

      nephew_hash_data = to_string(nephew.hash)
      stored_uncle_transaction_hash = transaction_hash()
      new_uncle_transaction_hash = transaction_hash()

      stub(EthereumJSONRPC.Mox, :json_rpc, fn requests, _ ->
        {:ok,
         Enum.map(requests, fn %{
                                 id: id,
                                 method: "eth_getUncleByBlockHashAndIndex",
                                 params: [^nephew_hash_data, index_data]
                               } ->
           result =
             case index_data do
               "0x0" -> uncle_json(stored_uncle.hash, stored_uncle.number, stored_uncle_transaction_hash)
               "0x1" -> uncle_json(new_uncle_hash, stored_uncle.number + 1, new_uncle_transaction_hash)
             end

           %{id: id, result: result}
         end)}
      end)

      UncleBlock.Supervisor.Case.start_supervised!(
        block_fetcher: %Block.Fetcher{json_rpc_named_arguments: json_rpc_named_arguments, task_supervisor: nil}
      )

      wait(fn -> fetched_relation!(nephew.hash, stored_uncle.hash) end)

      wait_for_results(fn ->
        Repo.one!(from(fork in Chain.Transaction.Fork, where: fork.hash == ^new_uncle_transaction_hash))
      end)

      assert %Chain.Block{consensus: true, refetch_needed: true} = Repo.get!(Chain.Block, stored_uncle.hash)
      assert %Chain.Block{consensus: false} = Repo.get!(Chain.Block, new_uncle_hash)

      assert [{^new_uncle_hash, ^new_uncle_transaction_hash}] =
               Repo.all(from(fork in Chain.Transaction.Fork, select: {fork.uncle_hash, fork.hash}))

      assert is_nil(Repo.get(Chain.Transaction, stored_uncle_transaction_hash))
    end
  end

  defp block_fetcher(json_rpc_named_arguments) do
    %Block.Fetcher{
      json_rpc_named_arguments: json_rpc_named_arguments,
      callback_module: UncleBlock,
      task_supervisor: nil
    }
  end

  # raises `Ecto.NoResultsError` until the relation is marked as fetched
  defp fetched_relation!(nephew_hash, uncle_hash) do
    Repo.one!(
      from(relation in Chain.Block.SecondDegreeRelation,
        where:
          relation.nephew_hash == ^nephew_hash and relation.uncle_hash == ^uncle_hash and
            not is_nil(relation.uncle_fetched_at)
      )
    )
  end

  defp uncle_json(%Hash{} = hash, number, %Hash{} = transaction_hash) do
    hash_data = to_string(hash)
    number_quantity = integer_to_quantity(number)

    %{
      "author" => "0xe2ac1c6843a33f81ae4935e5ef1277a392990381",
      "difficulty" => "0xfffffffffffffffffffffffffffffffe",
      "extraData" => "0xd583010a068650617269747986312e32362e32826c69",
      "gasLimit" => "0x7a1200",
      "gasUsed" => "0x0",
      "hash" => hash_data,
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
          "blockHash" => hash_data,
          "blockNumber" => number_quantity,
          "chainId" => "0x4d",
          "condition" => nil,
          "creates" => "0xffc87239eb0267bc3ca2cd51d12fbf278e02ccb4",
          "from" => "0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca",
          "gas" => "0x47b760",
          "gasPrice" => "0x174876e800",
          "hash" => to_string(transaction_hash),
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
      "uncles" => []
    }
  end

  defp wait(producer) do
    producer.()
  rescue
    Ecto.NoResultsError ->
      Process.sleep(100)
      wait(producer)
  end
end
