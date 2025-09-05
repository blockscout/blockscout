defmodule Indexer.Fetcher.EmptyBlocksSanitizerTest do
  # `async: false` due to use of named GenServer
  use EthereumJSONRPC.Case, async: false
  use Explorer.DataCase, async: false

  import Mox

  alias Indexer.Fetcher.EmptyBlocksSanitizer
  alias Explorer.Chain.Block

  @head_offset 1

  # We decrease the number of blocks required to be inserted for the test
  # in order to make it faster and to prevent filling the database with lots of trash.
  # Otherwise, with default offset of `1000`, the tests start to flake periodically.
  setup_all do
    opts = Application.get_env(:indexer, EmptyBlocksSanitizer)
    new_opts = Keyword.put(opts, :head_offset, @head_offset)
    Application.put_env(:indexer, EmptyBlocksSanitizer, new_opts)
    :ok
  end

  setup :set_mox_global
  setup :verify_on_exit!

  # Uncomment if you need to see what queries are sent to the Postgres
  # (check the database logs)
  #
  # setup do
  #   Repo.query("load 'auto_explain';")
  #   Repo.query("SET auto_explain.log_min_duration = 0;")
  #   Repo.query("SET auto_explain.log_analyze = true;")
  #   :ok
  # end

  @moduletag [capture_log: true, no_geth: true]

  test "process db-non-empty blocks", %{json_rpc_named_arguments: json_rpc_named_arguments} do
    # Setup
    block_to_process = insert(:block, is_empty: nil)
    _transaction = insert(:transaction) |> with_block(block_to_process)
    populate_database_with_dummy_blocks()
    assert Repo.get!(Block, block_to_process.hash).is_empty == nil, "precondition to check setup correctness"

    EmptyBlocksSanitizer.Supervisor.Case.start_supervised!(json_rpc_named_arguments: json_rpc_named_arguments)

    processed_block =
      wait_for_results(fn ->
        Repo.one!(
          from(block in Block,
            where: block.hash == ^block_to_process.hash and block.updated_at != ^block_to_process.updated_at
          )
        )
      end)

    assert processed_block.is_empty == false, "invalid `is_empty` value set for processed block"
    assert processed_block.refetch_needed == false, "invalid `refetch_needed` value set for processed block"
  end

  test "process db-empty blocks without transactions", %{json_rpc_named_arguments: json_rpc_named_arguments} do
    # Setup
    block_to_process = insert(:block, is_empty: nil)
    populate_database_with_dummy_blocks()
    assert Repo.get!(Block, block_to_process.hash).is_empty == nil, "precondition to check setup correctness"

    # Setup jsonrpc client
    encoded_expected_block_number = "0x" <> Integer.to_string(block_to_process.number, 16)

    if json_rpc_named_arguments[:transport] == EthereumJSONRPC.Mox do
      EthereumJSONRPC.Mox
      |> expect(
        :json_rpc,
        fn [
             %{
               id: id,
               method: "eth_getBlockByNumber",
               params: [^encoded_expected_block_number, false]
             }
           ],
           _options ->
          eth_get_block_by_number_response(id, block_to_process.number, block_to_process.hash, [])
        end
      )
    end

    EmptyBlocksSanitizer.Supervisor.Case.start_supervised!(json_rpc_named_arguments: json_rpc_named_arguments)

    processed_block =
      wait_for_results(fn ->
        Repo.one!(
          from(block in Block,
            where: block.hash == ^block_to_process.hash and block.updated_at != ^block_to_process.updated_at
          )
        )
      end)

    assert processed_block.is_empty == true, "invalid `is_empty` value set for processed block"
    assert processed_block.refetch_needed == false, "invalid `refetch_needed` value set for processed block"
  end

  test "process db-empty blocks with transactions", %{json_rpc_named_arguments: json_rpc_named_arguments} do
    # Setup
    block_to_process = insert(:block, is_empty: nil)
    populate_database_with_dummy_blocks()
    assert Repo.get!(Block, block_to_process.hash).is_empty == nil, "precondition to check setup correctness"

    # Setup jsonrpc client
    encoded_expected_block_number = "0x" <> Integer.to_string(block_to_process.number, 16)
    transaction_hash = "0x0000000000000000000000000000000000000000000000000000000000000001"

    if json_rpc_named_arguments[:transport] == EthereumJSONRPC.Mox do
      EthereumJSONRPC.Mox
      |> expect(
        :json_rpc,
        fn [
             %{
               id: id,
               method: "eth_getBlockByNumber",
               params: [^encoded_expected_block_number, false]
             }
           ],
           _options ->
          eth_get_block_by_number_response(id, encoded_expected_block_number, block_to_process.hash, [transaction_hash])
        end
      )
    end

    EmptyBlocksSanitizer.Supervisor.Case.start_supervised!(json_rpc_named_arguments: json_rpc_named_arguments)

    processed_block =
      wait_for_results(fn ->
        Repo.one!(
          from(block in Block,
            where: block.hash == ^block_to_process.hash and block.updated_at != ^block_to_process.updated_at
          )
        )
      end)

    assert processed_block.is_empty == nil, "invalid `is_empty` value set for processed block"
    assert processed_block.refetch_needed == true, "invalid `refetch_needed` value set for processed block"
  end

  test "only old enough blocks are sanitized", %{json_rpc_named_arguments: json_rpc_named_arguments} do
    # Setup
    block_to_process = insert(:block, is_empty: nil)
    insert(:transaction) |> with_block(block_to_process)

    Enum.each(1..@head_offset, fn _index ->
      insert(:block, is_empty: nil)
    end)

    assert Repo.one!(from(b in Block, select: count("*"), where: is_nil(b.is_empty))) == @head_offset + 1

    EmptyBlocksSanitizer.Supervisor.Case.start_supervised!(json_rpc_named_arguments: json_rpc_named_arguments)

    wait_for_results(fn ->
      Repo.one!(
        from(block in Block,
          where: block.hash == ^block_to_process.hash and block.updated_at != ^block_to_process.updated_at
        )
      )
    end)

    assert Repo.one!(from(b in Block, select: count("*"), where: is_nil(b.is_empty))) == @head_offset
  end

  defp populate_database_with_dummy_blocks() do
    Enum.each(1..@head_offset, fn _index ->
      insert(:block, is_empty: true)
    end)
  end

  defp eth_get_block_by_number_response(id, encoded_block_number, block_hash, transaction_hashes) do
    {:ok,
     [
       %{
         id: id,
         result: %{
           "difficulty" => "0x0",
           "gasLimit" => "0x0",
           "gasUsed" => "0x0",
           "hash" => block_hash,
           "extraData" => "0x0",
           "logsBloom" => "0x0",
           "miner" => "0x0",
           "number" => encoded_block_number,
           "parentHash" => "0x0",
           "receiptsRoot" => "0x0",
           "size" => "0x0",
           "sha3Uncles" => "0x0",
           "stateRoot" => "0x0",
           "timestamp" => "0x0",
           "totalDifficulty" => "0x0",
           "transactions" => transaction_hashes,
           "transactionsRoot" => "0x0",
           "uncles" => []
         }
       }
     ]}
  end
end
