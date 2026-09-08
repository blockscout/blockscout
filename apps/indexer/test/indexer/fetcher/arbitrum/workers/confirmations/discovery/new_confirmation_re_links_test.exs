# SPDX-License-Identifier: LicenseRef-Blockscout
if Application.get_env(:explorer, :chain_type) == :arbitrum do
  defmodule Indexer.Fetcher.Arbitrum.Workers.Confirmations.Discovery.NewConfirmationReLinksTest do
    use Indexer.Fetcher.Arbitrum.Workers.Confirmations.Discovery.TestCase

    # See `Indexer.Fetcher.Arbitrum.Workers.Confirmations.Discovery.TestCase` for
    # the conventions this suite of files follows.

    # The rollup blocks of a batch can hold a link to a parent chain transaction
    # which is not the confirmation of those blocks. A re-org of the parent chain
    # gives this state: the discovery imported the confirmation before its parent
    # chain block became safe, and the re-org replaced that transaction. After the
    # re-org the parent chain holds no log of the replaced transaction.
    #
    # A new confirmation of the same rollup blocks must take those blocks from the
    # replaced transaction. This group holds one scenario per position of the
    # replaced blocks within the batch of the event, and one scenario where the
    # replaced blocks are in the batch below.
    #
    # The discovery of the confirmations does not handle a re-org yet. Thus five
    # scenarios of this group carry the tag of a defect, and the last one holds the
    # current behavior.
    describe "perform/5 with a new confirmation which re-links rollup blocks" do
      # The database has one batch with the rollup blocks 1..10. The blocks 9 and 10
      # are linked to a parent chain transaction which is not the confirmation of
      # this range. The blocks 1..8 are not confirmed.
      #
      # Such a state occurs after a re-org, or after a wrong link. The event points
      # to the rollup block 10. Thus the discovery takes the blocks 9 and 10 from
      # the other transaction, and links the full batch to the new confirmation.
      test "re-links the blocks on top of the batch which were confirmed by another transaction", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        batch = seed_batch(@rollup_first_block, 10, @commitment_l1_block)

        wrong_confirmation = insert_confirmation(@earlier_confirmation_l1_block)
        mark_confirmed(9..10, wrong_confirmation)

        confirmation_transaction_hash = to_string(transaction_hash())

        expect_discovery(rollup_block_hash(batch, 10), confirmation_transaction_hash)

        assert :ok == discover(json_rpc_named_arguments)

        # The full batch is linked to the new confirmation. The other transaction
        # keeps no block.
        confirmation = Repo.get_by!(LifecycleTransaction, hash: confirmation_transaction_hash)
        assert confirmed_blocks(confirmation) == Enum.to_list(@rollup_first_block..10)
        assert confirmed_blocks(wrong_confirmation) == []
      end

      # The database has one batch with the rollup blocks 1..10. All blocks of it are
      # linked to a parent chain transaction which is not the confirmation of this
      # range.
      #
      # Such a state occurs after a re-org. The discovery imported the confirmation
      # before its parent chain block became safe, and the re-org replaced that
      # transaction. After the re-org the parent chain does not hold the log of the
      # replaced transaction.
      #
      # The event points to the rollup block 10. It confirms the same blocks as the
      # replaced transaction. Thus the discovery must take the blocks 1..10 from the
      # other transaction, and it must link the full batch to the new confirmation.
      # The test "re-links the blocks on top of the batch which were confirmed by
      # another transaction" holds the same re-link for a part of the batch.
      #
      # The batch holds no unconfirmed block, and the number of its confirmed blocks
      # is equal to the size of the batch. The discovery reads this state as a batch
      # which needs no work, and it gives no block to the confirmation. The re-link
      # of the blocks on top of a batch starts from the highest unconfirmed block of
      # the batch. In this state no block is unconfirmed, thus the re-link does not
      # start. The discovery writes nothing, and it returns `:confirmation_missed`.
      #
      # The first part of the test keeps `:confirmation_missed`, which is the current
      # result. The second part changes nothing in the database. The indexer has
      # nothing to add, because the batch is complete. Thus the repeated run of the
      # same parent chain range must give `:ok`. The discovery gives
      # `:confirmation_missed` again, and the test fails on that assertion.
      # Therefore the historical discovery reads this range again and again.
      @tag skip: "Defect: a batch confirmed in full by another transaction repeats the range"
      test "re-links the batch which another transaction confirmed in full", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        batch = seed_batch(@rollup_first_block, 10, @commitment_l1_block)

        wrong_confirmation = insert_confirmation(@earlier_confirmation_l1_block)
        mark_confirmed(@rollup_first_block..10, wrong_confirmation)

        confirmation_transaction_hash = to_string(transaction_hash())

        expect_discovery(rollup_block_hash(batch, 10), confirmation_transaction_hash)

        assert :confirmation_missed == discover(json_rpc_named_arguments)

        assert Repo.get_by(LifecycleTransaction, hash: confirmation_transaction_hash) == nil
        assert confirmed_blocks(wrong_confirmation) == Enum.to_list(@rollup_first_block..10)

        assert :ok == discover(json_rpc_named_arguments)

        confirmation = Repo.get_by!(LifecycleTransaction, hash: confirmation_transaction_hash)
        assert confirmed_blocks(confirmation) == Enum.to_list(@rollup_first_block..10)
        assert confirmed_blocks(wrong_confirmation) == []
      end

      # The database has one batch of the blocks 1..10. The blocks 1..5 are linked to
      # a confirmation which a re-org replaced. The discovery imported that
      # confirmation before its parent chain block became safe, and the re-org
      # replaced the transaction. Thus the parent chain holds no log of it. The blocks
      # 6..10 are not confirmed.
      #
      # The event points to the rollup block 10. It confirms the blocks of the
      # replaced transaction and the blocks above them. Thus the discovery must take
      # the blocks 1..5 from the replaced transaction, and it must link the full batch
      # to the new confirmation.
      #
      # The re-link of the blocks of a batch starts from the highest unconfirmed block
      # of the batch, and it extends upward only. Here the unconfirmed blocks are the
      # blocks 6..10, and the highest of them is the last block of the range. Thus the
      # re-link adds no block, and the selection holds five blocks. The lookup finds no
      # earlier confirmation, thus the range of the confirmation starts at the block 1
      # and holds ten blocks. The discovery reads this difference as an incomplete
      # batch. It writes nothing, and it returns `:confirmation_missed`.
      #
      # The test "re-links the blocks on top of the batch which were confirmed by
      # another transaction" holds the re-link of the upper blocks of a batch, and that
      # re-link works. This test is the only one which holds the re-link of the lower
      # blocks of a batch.
      #
      # The first part of the test keeps `:confirmation_missed`, which is the current
      # result. The second part changes nothing in the database. The database holds the
      # whole batch already, thus the indexer has nothing to add. Therefore the
      # repeated run of the same parent chain range must give `:ok`. The discovery
      # gives `:confirmation_missed` again, and the test fails on that assertion.
      # Therefore the historical discovery reads this range again and again.
      #
      # The correction of the defect gives `:ok` and the full batch in the first run.
      # Thus the person who removes the tag also removes the assertions of the first
      # part.
      @tag skip: "Defect: a re-org which replaced the confirmation of the lower blocks of a batch repeats the range"
      test "re-links the lower blocks of the batch which a re-org replaced", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        batch = seed_batch(@rollup_first_block, 10, @commitment_l1_block)

        replaced_confirmation = insert_confirmation(@earlier_confirmation_l1_block)
        mark_confirmed(@rollup_first_block..5, replaced_confirmation)

        confirmation_transaction_hash = to_string(transaction_hash())

        expect_discovery(rollup_block_hash(batch, 10), confirmation_transaction_hash)

        assert :confirmation_missed == discover(json_rpc_named_arguments)

        assert Repo.get_by(LifecycleTransaction, hash: confirmation_transaction_hash) == nil
        assert confirmed_blocks(replaced_confirmation) == Enum.to_list(@rollup_first_block..5)
        assert unconfirmed_blocks() == Enum.to_list(6..10)

        assert :ok == discover(json_rpc_named_arguments)

        confirmation = Repo.get_by!(LifecycleTransaction, hash: confirmation_transaction_hash)
        assert confirmed_blocks(confirmation) == Enum.to_list(@rollup_first_block..10)
        assert confirmed_blocks(replaced_confirmation) == []
        assert unconfirmed_blocks() == []
      end

      # The database has one batch of the blocks 1..10. Only the block 5 is linked to
      # a confirmation which a re-org replaced. The parent chain holds no log of that
      # transaction. The other blocks of the batch are not confirmed.
      #
      # A re-org gives this state when the replaced transaction confirmed the block 5
      # as the top of its range, and another transaction confirmed the blocks below it.
      #
      # The event points to the rollup block 10. Thus the discovery must take the
      # block 5 from the replaced transaction, and it must link the full batch to the
      # new confirmation.
      #
      # The unconfirmed blocks of the batch are the blocks 1..4 and 6..10. They hold a
      # gap between the blocks 4 and 6. The discovery reads a gap as a database
      # inconsistency. Thus it writes nothing, and it returns `:confirmation_missed`.
      #
      # The test "postpones the confirmation when the blocks of the batch hold a gap"
      # holds the same gap of the selection. In that test the block 5 holds no link to
      # its batch, thus the indexer ends the postponement. This test is the only one
      # where a gap of the selection comes from a link to a confirmation. No change of
      # the indexer can end this postponement, because the link of the block 5 to its
      # batch exists already.
      #
      # The first part of the test keeps `:confirmation_missed`, which is the current
      # result. The second part changes nothing in the database, thus the repeated run
      # must give `:ok`. The discovery gives `:confirmation_missed` again, and the test
      # fails on that assertion.
      #
      # The correction of the defect gives `:ok` and the full batch in the first run.
      # Thus the person who removes the tag also removes the assertions of the first
      # part.
      @tag skip: "Defect: a re-org which replaced the confirmation of one block of a batch repeats the range"
      test "re-links the block in the middle of the batch which a re-org replaced", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        batch = seed_batch(@rollup_first_block, 10, @commitment_l1_block)

        replaced_confirmation = insert_confirmation(@earlier_confirmation_l1_block)
        mark_confirmed([5], replaced_confirmation)

        confirmation_transaction_hash = to_string(transaction_hash())

        expect_discovery(rollup_block_hash(batch, 10), confirmation_transaction_hash)

        assert :confirmation_missed == discover(json_rpc_named_arguments)

        assert Repo.get_by(LifecycleTransaction, hash: confirmation_transaction_hash) == nil
        assert confirmed_blocks(replaced_confirmation) == [5]
        assert unconfirmed_blocks() == Enum.to_list(@rollup_first_block..4) ++ Enum.to_list(6..10)

        assert :ok == discover(json_rpc_named_arguments)

        confirmation = Repo.get_by!(LifecycleTransaction, hash: confirmation_transaction_hash)
        assert confirmed_blocks(confirmation) == Enum.to_list(@rollup_first_block..10)
        assert confirmed_blocks(replaced_confirmation) == []
        assert unconfirmed_blocks() == []
      end

      # The database has one batch of the blocks 1..10. The blocks 1..5 are linked to
      # a confirmation which a re-org replaced. The parent chain holds no log of that
      # transaction. The blocks 6..10 are not confirmed.
      #
      # The event points to the rollup block 5. Thus the new confirmation covers
      # exactly the blocks of the replaced transaction. The discovery must take the
      # blocks 1..5 from that transaction, and the blocks 6..10 must wait for the next
      # confirmation.
      #
      # The discovery selects the unconfirmed blocks of the batch up to the block 5.
      # That selection is empty, because the replaced transaction holds every block of
      # the range. Thus the discovery counts the confirmed blocks of the batch. The
      # count is 5, and the batch holds 10 blocks. Such a batch is not complete, and
      # the discovery does not use it. It stops before the lookup of an earlier
      # confirmation, it writes nothing, and it returns `:confirmation_missed`.
      #
      # The test "postpones the confirmation when the batch is linked to a part of its
      # blocks only" reaches the same count of the confirmed blocks. In that test the
      # other blocks of the batch hold no link to it, thus the indexer ends the
      # postponement. This test is the only one where the whole batch is in the
      # database and the count still shows an incomplete batch.
      #
      # The first part of the test keeps `:confirmation_missed`, which is the current
      # result. The second part changes nothing in the database, thus the repeated run
      # must give `:ok`. The discovery gives `:confirmation_missed` again, and the test
      # fails on that assertion.
      #
      # The correction of the defect gives `:ok` and the blocks 1..5 in the first run.
      # Thus the person who removes the tag also removes the assertions of the first
      # part.
      @tag skip: "Defect: a re-org which replaced the confirmation of the whole range of the event repeats the range"
      test "re-links the whole range of the event which a re-org replaced", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        batch = seed_batch(@rollup_first_block, 10, @commitment_l1_block)

        replaced_confirmation = insert_confirmation(@earlier_confirmation_l1_block)
        mark_confirmed(@rollup_first_block..5, replaced_confirmation)

        confirmation_transaction_hash = to_string(transaction_hash())

        expect_discovery(rollup_block_hash(batch, 5), confirmation_transaction_hash)

        assert :confirmation_missed == discover(json_rpc_named_arguments)

        assert Repo.get_by(LifecycleTransaction, hash: confirmation_transaction_hash) == nil
        assert confirmed_blocks(replaced_confirmation) == Enum.to_list(@rollup_first_block..5)
        assert unconfirmed_blocks() == Enum.to_list(6..10)

        assert :ok == discover(json_rpc_named_arguments)

        confirmation = Repo.get_by!(LifecycleTransaction, hash: confirmation_transaction_hash)
        assert confirmed_blocks(confirmation) == Enum.to_list(@rollup_first_block..5)
        assert confirmed_blocks(replaced_confirmation) == []
        assert unconfirmed_blocks() == Enum.to_list(6..10)
      end

      # The database has two batches: the blocks 1..10 and the blocks 11..20. Every
      # block of the first batch is linked to a confirmation which a re-org replaced.
      # The parent chain holds no log of that transaction, and it holds no other
      # confirmation below the event. The blocks 11..20 are not confirmed.
      #
      # The event points to the rollup block 20. Thus the confirmation covers the
      # blocks 11..20. The blocks of the first batch belong to a transaction which the
      # parent chain does not hold any more.
      #
      # The discovery collects the blocks 11..20 and moves one batch down. The database
      # shows that all blocks of the first batch are confirmed. Thus the walk stops
      # there, and it stops before the lookup of the logs of that batch. Therefore the
      # discovery never learns that the parent chain holds no log of the replaced
      # transaction, and the wrong links stay in the database.
      #
      # The result is `:ok` and the blocks 11..20, which is the current behavior. The
      # discovery of the confirmations does not handle re-orgs yet. This test is the
      # only one which shows how the discovery behaves when a re-org replaced the
      # confirmation of a batch below the event. The test holds the current behavior,
      # and not a defect, because a re-org repair is separate work.
      #
      # When that work lands, this test changes: the discovery must drop the links of
      # the replaced transaction and give the blocks 1..20 to the new confirmation. The
      # walk of this test is the walk of the test "stops at the previous batch when all
      # of its blocks are already confirmed". In that test the confirmation of the
      # batch below is on the parent chain, thus the stop of the walk is correct there.
      test "keeps the confirmation of the previous batch which a re-org replaced", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        seed_batch(@rollup_first_block, 10, @previous_commitment_l1_block)
        batch = seed_batch(11, 20, @commitment_l1_block)

        replaced_confirmation = insert_confirmation(@earlier_confirmation_l1_block)
        mark_confirmed(@rollup_first_block..10, replaced_confirmation)

        confirmation_transaction_hash = to_string(transaction_hash())

        expect_discovery(rollup_block_hash(batch, 20), confirmation_transaction_hash)

        assert :ok == discover(json_rpc_named_arguments)

        confirmation = Repo.get_by!(LifecycleTransaction, hash: confirmation_transaction_hash)
        assert confirmed_blocks(confirmation) == Enum.to_list(11..20)

        # The links of the replaced transaction stay as they are.
        assert confirmed_blocks(replaced_confirmation) == Enum.to_list(@rollup_first_block..10)
        assert unconfirmed_blocks() == []
      end
    end
  end
end
