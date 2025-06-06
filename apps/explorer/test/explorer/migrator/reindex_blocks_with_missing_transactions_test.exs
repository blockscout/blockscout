defmodule Explorer.Migrator.ReindexBlocksWithMissingTransactionsTest do
  use Explorer.DataCase, async: false

  import Mox

  alias Explorer.Chain.Block
  alias Explorer.Migrator.{MigrationStatus, ReindexBlocksWithMissingTransactions}
  alias Explorer.Repo

  setup :set_mox_global
  setup :verify_on_exit!

  setup do
    configuration = Application.get_env(:explorer, ReindexBlocksWithMissingTransactions)

    Application.put_env(
      :explorer,
      ReindexBlocksWithMissingTransactions,
      Keyword.merge(configuration, batch_size: 1, concurrency: 1)
    )

    on_exit(fn ->
      Application.put_env(:explorer, ReindexBlocksWithMissingTransactions, configuration)
    end)
  end

  test "Reindex blocks with missing transactions" do
    %{block: %{number: block_number_correct}} =
      :transaction
      |> insert()
      |> with_block()

    correct_block_number_quantity = EthereumJSONRPC.integer_to_quantity(block_number_correct)

    %{block: %{number: block_number_incorrect}} =
      :transaction
      |> insert()
      |> with_block()

    incorrect_block_number_quantity = EthereumJSONRPC.integer_to_quantity(block_number_incorrect)

    expect(EthereumJSONRPC.Mox, :json_rpc, 2, fn
      [
        %{
          id: id,
          method: "eth_getBlockByNumber",
          params: [^correct_block_number_quantity, true]
        }
      ],
      _ ->
        block_fake_response(id, block_number_correct, 1)

      [
        %{
          id: id,
          method: "eth_getBlockByNumber",
          params: [^incorrect_block_number_quantity, true]
        }
      ],
      _ ->
        block_fake_response(id, block_number_incorrect, 2)
    end)

    assert MigrationStatus.get_status("reindex_blocks_with_missing_transactions") == nil

    ReindexBlocksWithMissingTransactions.start_link([])

    wait_for_results(fn ->
      Repo.one!(
        from(ms in MigrationStatus,
          where: ms.migration_name == ^"reindex_blocks_with_missing_transactions" and ms.status == "completed"
        )
      )
    end)

    assert %{consensus: true, refetch_needed: false} = Repo.get_by(Block, number: block_number_correct)
    assert %{consensus: true, refetch_needed: true} = Repo.get_by(Block, number: block_number_incorrect)
  end

  defp block_fake_response(id, block_number, transactions_count) do
    {:ok,
     [
       %{
         id: id,
         result: %{
           "difficulty" => "0x0",
           "gasLimit" => "0x0",
           "gasUsed" => "0x0",
           "hash" => "0x5b28c1bfd3a15230c9a46b399cd0f9a6920d432e85381cc6a140b06e8410112f",
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
           "transactions" =>
             Enum.map(0..(transactions_count - 1), fn index ->
               %{
                 "blockHash" => "0x5b28c1bfd3a15230c9a46b399cd0f9a6920d432e85381cc6a140b06e8410112f",
                 "blockNumber" => block_number,
                 "from" => "0x0",
                 "gas" => "0x0",
                 "gasPrice" => "0x0",
                 "hash" => "0x5626d3aaf5f7666f0d82919178b0ba0880683e8531b6718a83ca946d337a81c9",
                 "input" => "0x",
                 "nonce" => "0x0",
                 "r" => "0x0",
                 "s" => "0x0",
                 "to" => "0x0",
                 "transactionIndex" => EthereumJSONRPC.integer_to_quantity(index),
                 "v" => "0x0",
                 "value" => "0x0"
               }
             end),
           "transactionsRoot" => "0x0",
           "uncles" => []
         }
       }
     ]}
  end
end
