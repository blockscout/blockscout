# SPDX-License-Identifier: LicenseRef-Blockscout
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
    # The migrator walks every block number from the chain's max down to 0, one
    # number per iteration with batch_size: 1 and concurrency: 1. Pinning the
    # blocks to low explicit numbers keeps that walk short regardless of how far
    # the global `block_number` factory sequence has advanced in this test run.
    %{block: %{number: block_number_correct}} =
      :transaction
      |> insert()
      |> with_block(insert(:block, number: 1))

    correct_block_number_quantity = EthereumJSONRPC.integer_to_quantity(block_number_correct)

    %{block: %{number: block_number_incorrect}} =
      :transaction
      |> insert()
      |> with_block(insert(:block, number: 2))

    incorrect_block_number_quantity = EthereumJSONRPC.integer_to_quantity(block_number_incorrect)

    expect(EthereumJSONRPC.Mox, :json_rpc, 2, fn
      [
        %{
          id: id,
          method: "eth_getBlockTransactionCountByNumber",
          params: [^correct_block_number_quantity]
        }
      ],
      _ ->
        {:ok, [%{id: id, result: "0x1", jsonrpc: "2.0"}]}

      [
        %{
          id: id,
          method: "eth_getBlockTransactionCountByNumber",
          params: [^incorrect_block_number_quantity]
        }
      ],
      _ ->
        {:ok, [%{id: id, result: "0x2", jsonrpc: "2.0"}]}
    end)

    assert MigrationStatus.get_status("reindex_blocks_with_missing_transactions") == nil

    ReindexBlocksWithMissingTransactions.start_link([])

    wait_for_results(
      fn ->
        Repo.one!(
          from(ms in MigrationStatus,
            where: ms.migration_name == ^"reindex_blocks_with_missing_transactions" and ms.status == "completed"
          )
        )
      end,
      60
    )

    assert %{consensus: true, refetch_needed: false} = Repo.get_by(Block, number: block_number_correct)
    assert %{consensus: true, refetch_needed: true} = Repo.get_by(Block, number: block_number_incorrect)
  end
end
