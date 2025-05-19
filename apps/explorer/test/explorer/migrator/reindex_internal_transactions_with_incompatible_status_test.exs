defmodule Explorer.Migrator.ReindexInternalTransactionsWithIncompatibleStatusTest do
  use Explorer.DataCase, async: false

  alias Explorer.Chain.PendingBlockOperation
  alias Explorer.Migrator.{ReindexInternalTransactionsWithIncompatibleStatus, MigrationStatus}
  alias Explorer.Repo

  describe "Migrate incorrect internal transactions" do
    setup do
      config = Application.get_env(:ethereum_jsonrpc, EthereumJSONRPC.Geth)
      Application.put_env(:ethereum_jsonrpc, EthereumJSONRPC.Geth, Keyword.put(config, :block_traceable?, true))

      on_exit(fn -> Application.put_env(:ethereum_jsonrpc, EthereumJSONRPC.Geth, config) end)
    end

    test "Adds new pbo for incorrect internal transactions" do
      incorrect_block_numbers =
        Enum.map(1..5, fn i ->
          block = insert(:block)
          transaction = :transaction |> insert() |> with_block(block, status: :error)

          insert(:internal_transaction,
            index: 10,
            transaction: transaction,
            block: block,
            block_number: block.number,
            block_index: i,
            error: nil
          )

          block.number
        end)

      Enum.each(1..5, fn i ->
        block = insert(:block)
        transaction = :transaction |> insert() |> with_block(block, status: :error)

        insert(:internal_transaction,
          index: 10,
          transaction: transaction,
          block: block,
          block_number: block.number,
          block_index: i,
          error: "error",
          output: nil
        )
      end)

      Enum.each(1..5, fn i ->
        block = insert(:block)
        transaction = :transaction |> insert() |> with_block(block, status: :ok)

        insert(:internal_transaction,
          index: 10,
          transaction: transaction,
          block: block,
          block_number: block.number,
          block_index: i,
          error: nil
        )
      end)

      assert MigrationStatus.get_status("reindex_internal_transactions_with_incompatible_status") == nil
      assert Repo.all(PendingBlockOperation) == []

      ReindexInternalTransactionsWithIncompatibleStatus.start_link([])
      Process.sleep(100)

      pbo_block_numbers =
        PendingBlockOperation
        |> Repo.all()
        |> Enum.map(& &1.block_number)
        |> Enum.sort()

      assert incorrect_block_numbers == pbo_block_numbers

      assert MigrationStatus.get_status("reindex_internal_transactions_with_incompatible_status") == "completed"
    end
  end
end
