# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Migrator.ReindexBlocksWithUncatalogedTokenTransfersTest do
  use Explorer.DataCase, async: false

  alias Explorer.Migrator.{MigrationStatus, ReindexBlocksWithUncatalogedTokenTransfers}
  alias Explorer.Repo
  alias Explorer.Utility.MissingBlockRange

  setup do
    Repo.delete_all(
      from(ms in MigrationStatus, where: ms.migration_name == ^"reindex_blocks_with_uncataloged_token_transfers")
    )

    configuration = Application.get_env(:explorer, ReindexBlocksWithUncatalogedTokenTransfers)

    Application.put_env(
      :explorer,
      ReindexBlocksWithUncatalogedTokenTransfers,
      Keyword.merge(configuration || [], batch_size: 100, concurrency: 1)
    )

    on_exit(fn ->
      Application.put_env(:explorer, ReindexBlocksWithUncatalogedTokenTransfers, configuration)
    end)
  end

  test "adds blocks with uncataloged token transfers to missing block ranges" do
    uncataloged_block = insert(:block)
    address = insert(:address)

    insert(:token_transfer_log,
      transaction:
        insert(:transaction,
          block_number: uncataloged_block.number,
          block_hash: uncataloged_block.hash,
          cumulative_gas_used: 0,
          gas_used: 0,
          index: 0
        ),
      block: uncataloged_block,
      block_number: uncataloged_block.number,
      address_hash: address.hash,
      address: address
    )

    cataloged_block = insert(:block)

    cataloged_transaction =
      insert(:transaction,
        block_number: cataloged_block.number,
        block_hash: cataloged_block.hash,
        cumulative_gas_used: 0,
        gas_used: 0,
        index: 0
      )

    cataloged_log =
      insert(:token_transfer_log,
        transaction: cataloged_transaction,
        block: cataloged_block,
        block_number: cataloged_block.number,
        address_hash: address.hash,
        address: address
      )

    insert(:token_transfer,
      transaction: cataloged_transaction,
      block: cataloged_block,
      block_number: cataloged_block.number,
      log_index: cataloged_log.index
    )

    assert MigrationStatus.get_status("reindex_blocks_with_uncataloged_token_transfers") == nil

    ReindexBlocksWithUncatalogedTokenTransfers.start_link([])

    wait_for_results(
      fn ->
        Repo.one!(
          from(ms in MigrationStatus,
            where: ms.migration_name == ^"reindex_blocks_with_uncataloged_token_transfers" and ms.status == "completed"
          )
        )
      end,
      60
    )

    ranges = Repo.all(MissingBlockRange)

    assert Enum.any?(ranges, fn range ->
             range.from_number >= uncataloged_block.number and range.to_number <= uncataloged_block.number
           end)

    refute Enum.any?(ranges, fn range ->
             range.from_number >= cataloged_block.number and range.to_number <= cataloged_block.number
           end)
  end
end
