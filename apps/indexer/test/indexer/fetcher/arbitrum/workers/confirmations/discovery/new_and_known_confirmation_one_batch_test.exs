# SPDX-License-Identifier: LicenseRef-Blockscout
if Application.get_env(:explorer, :chain_type) == :arbitrum do
  defmodule Indexer.Fetcher.Arbitrum.Workers.Confirmations.Discovery.NewAndKnownConfirmationOneBatchTest do
    use Indexer.Fetcher.Arbitrum.Workers.Confirmations.Discovery.TestCase

    # See `Indexer.Fetcher.Arbitrum.Workers.Confirmations.Discovery.TestCase` for
    # the conventions this suite of files follows.

    # One batch can hold the rollup blocks of two confirmations: a confirmation is
    # not always aligned with the boundary of a batch. Then the database knows one of
    # them already, and the parent chain range holds the events of both.
    #
    # The discovery examines the rollup blocks of the new confirmation only, and it
    # never extends the confirmation which it knows already. Thus it must find the
    # boundary between the two confirmations within the batch. The state of the
    # database cannot give that boundary, because the batch is not confirmed in full.
    # The lookup of the parent chain gives it, and the lookup range ends one block
    # before the new confirmation.
    #
    # This group holds the four positions of the two events on the parent chain: the
    # known confirmation of the lower or of the upper blocks, and the known event in
    # the same parent chain block, in an older one, or in a newer one. Three of the
    # four scenarios give a defect, thus one batch is the state where the discovery
    # cannot split the blocks between a known confirmation and a new one.
    #
    # The group "perform/5 with a new confirmation and a known one in two batches"
    # holds the same four positions over two batches, where every scenario gives the
    # correct result.
    describe "perform/5 with a new confirmation and a known one in one batch" do
      # The database has one batch of the blocks 1..20. The known confirmation holds
      # the blocks 1..10 of that batch. Its parent chain block and its timestamp are
      # equal to the values in its event. Both events are in the parent chain block
      # 200: one parent chain block can hold two transactions which confirm a node.
      #
      # The new event points to the rollup block 20. Thus the new confirmation must
      # cover the blocks 11..20, and the known confirmation must keep the blocks 1..10.
      #
      # The lookup range of the new confirmation ends one block before the parent chain
      # block of that confirmation. Thus the range holds no log of the known
      # confirmation, and the discovery takes the block 1 as the start of the range of
      # the new confirmation. The selection of the blocks holds the blocks 11..20 only,
      # because the known confirmation holds the blocks below them. The discovery reads
      # this difference as an incomplete batch. It writes nothing for the new event, and
      # it returns `:confirmation_missed`.
      #
      # The test "splits two batches between the known lower confirmation and the new
      # upper one of the same parent chain block" holds the same pair of events over two
      # batches. There the walk stops at the fully confirmed batch below, and the result
      # is correct. This test is the only one where the known confirmation of the same
      # batch is in the parent chain block of the new confirmation.
      #
      # The second part of the test changes nothing in the database. The database holds
      # the whole batch already, thus the indexer has nothing to add. Therefore the
      # repeated run of the same parent chain range must give `:ok`. The discovery gives
      # `:confirmation_missed` again, and the test fails on that assertion.
      #
      # The correction of the defect gives `:ok` and the blocks 11..20 in the first run.
      # Thus the person who removes the tag also removes the assertions of the first
      # part.
      @tag skip: "Defect: a new confirmation above a known confirmation of the same batch repeats the range"
      test "splits one batch between the known lower confirmation and the new upper one of the same parent chain block",
           %{json_rpc_named_arguments: json_rpc_named_arguments} do
        batch = seed_batch(@rollup_first_block, 20, @commitment_l1_block)

        known_confirmation = insert_confirmation(@confirmation_l1_block, @confirmation_l1_timestamp)
        mark_confirmed(@rollup_first_block..10, known_confirmation)

        new_confirmation_transaction_hash = to_string(transaction_hash())

        expect_discovery_of([
          build_send_root_updated_log(
            rollup_block_hash(batch, 10),
            to_string(known_confirmation.hash),
            @confirmation_l1_block
          ),
          build_send_root_updated_log(
            rollup_block_hash(batch, 20),
            new_confirmation_transaction_hash,
            @confirmation_l1_block,
            log_index: 1,
            transaction_index: 1
          )
        ])

        assert :confirmation_missed == discover(json_rpc_named_arguments)

        assert Repo.get_by(LifecycleTransaction, hash: new_confirmation_transaction_hash) == nil
        assert confirmed_blocks(known_confirmation) == Enum.to_list(@rollup_first_block..10)
        assert unconfirmed_blocks() == Enum.to_list(11..20)

        assert :ok == discover(json_rpc_named_arguments)

        new_confirmation = Repo.get_by!(LifecycleTransaction, hash: new_confirmation_transaction_hash)
        assert confirmed_blocks(new_confirmation) == Enum.to_list(11..20)
        assert confirmed_blocks(known_confirmation) == Enum.to_list(@rollup_first_block..10)
        assert unconfirmed_blocks() == []
      end

      # The database has one batch of the blocks 1..20. The known confirmation holds
      # the blocks 11..20 of that batch. Its parent chain block and its timestamp are
      # equal to the values in its event. Both events are in the parent chain block
      # 200.
      #
      # The new event points to the rollup block 10. Thus the new confirmation covers
      # the blocks below the known one.
      #
      # The discovery selects the unconfirmed blocks of the batch up to the block 10.
      # The lookup range holds no log, because it ends one block before the parent chain
      # block of the new confirmation. The batch starts at the lowest-indexed rollup
      # block. Thus the new confirmation covers the blocks 1..10, and the discovery
      # never extends the known confirmation.
      #
      # The test "confirms the blocks below a later known confirmation of the same
      # batch" holds the same state of the database with the event of the known
      # confirmation outside the discovery range. This test is the only one where the
      # known confirmation of the upper blocks of the batch is in the parent chain block
      # of the new confirmation.
      test "splits one batch between the new lower confirmation and the known upper one of the same parent chain block",
           %{json_rpc_named_arguments: json_rpc_named_arguments} do
        batch = seed_batch(@rollup_first_block, 20, @commitment_l1_block)

        known_confirmation = insert_confirmation(@confirmation_l1_block, @confirmation_l1_timestamp)
        mark_confirmed(11..20, known_confirmation)

        new_confirmation_transaction_hash = to_string(transaction_hash())

        expect_discovery_of([
          build_send_root_updated_log(
            rollup_block_hash(batch, 10),
            new_confirmation_transaction_hash,
            @confirmation_l1_block
          ),
          build_send_root_updated_log(
            rollup_block_hash(batch, 20),
            to_string(known_confirmation.hash),
            @confirmation_l1_block,
            log_index: 1,
            transaction_index: 1
          )
        ])

        assert :ok == discover(json_rpc_named_arguments)

        new_confirmation = Repo.get_by!(LifecycleTransaction, hash: new_confirmation_transaction_hash)
        assert confirmed_blocks(new_confirmation) == Enum.to_list(@rollup_first_block..10)

        kept_confirmation = Repo.get_by!(LifecycleTransaction, hash: known_confirmation.hash)
        assert kept_confirmation.id == known_confirmation.id
        assert kept_confirmation.block_number == @confirmation_l1_block
        assert DateTime.compare(kept_confirmation.timestamp, known_confirmation.timestamp) == :eq
        assert confirmed_blocks(kept_confirmation) == Enum.to_list(11..20)

        assert unconfirmed_blocks() == []
      end

      # The database has one batch of the blocks 1..20. The known confirmation holds
      # the blocks 1..10 of that batch, and its event is in the parent chain block 200.
      # The new event is in the parent chain block 198, and it points to the rollup
      # block 20. Thus the known confirmation of the lower blocks is the newer one on
      # the parent chain.
      #
      # The new confirmation must cover the blocks 11..20, and the known confirmation
      # must keep the blocks 1..10.
      #
      # The lookup range of the new confirmation ends before the parent chain block of
      # the known confirmation. Thus the lookup finds no log, and the discovery takes
      # the block 1 as the start of the range of the new confirmation. The selection of
      # the blocks holds the blocks 11..20 only. The discovery reads this difference as
      # an incomplete batch. It writes nothing for the new event, and it returns
      # `:confirmation_missed`.
      #
      # The test "splits one batch between the known lower confirmation and the new
      # upper one of the same parent chain block" gives the same result with both events
      # in one parent chain block. This test is the only one where the known
      # confirmation of the lower blocks of the batch is newer than the new
      # confirmation.
      #
      # The second part of the test changes nothing in the database, thus the repeated
      # run must give `:ok`. The discovery gives `:confirmation_missed` again, and the
      # test fails on that assertion.
      #
      # The correction of the defect gives `:ok` and the blocks 11..20 in the first run.
      # Thus the person who removes the tag also removes the assertions of the first
      # part.
      @tag skip: "Defect: a new confirmation above a known confirmation of the same batch repeats the range"
      test "splits one batch when the known lower confirmation is newer on the parent chain", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        batch = seed_batch(@rollup_first_block, 20, @commitment_l1_block)

        known_confirmation = insert_confirmation(@confirmation_l1_block, @confirmation_l1_timestamp)
        mark_confirmed(@rollup_first_block..10, known_confirmation)

        new_confirmation_transaction_hash = to_string(transaction_hash())

        expect_discovery_of([
          build_send_root_updated_log(
            rollup_block_hash(batch, 20),
            new_confirmation_transaction_hash,
            @lower_confirmation_l1_block
          ),
          build_send_root_updated_log(
            rollup_block_hash(batch, 10),
            to_string(known_confirmation.hash),
            @confirmation_l1_block
          )
        ])

        assert :confirmation_missed == discover(json_rpc_named_arguments)

        assert Repo.get_by(LifecycleTransaction, hash: new_confirmation_transaction_hash) == nil
        assert confirmed_blocks(known_confirmation) == Enum.to_list(@rollup_first_block..10)
        assert unconfirmed_blocks() == Enum.to_list(11..20)

        assert :ok == discover(json_rpc_named_arguments)

        new_confirmation = Repo.get_by!(LifecycleTransaction, hash: new_confirmation_transaction_hash)
        assert new_confirmation.block_number == @lower_confirmation_l1_block
        assert confirmed_blocks(new_confirmation) == Enum.to_list(11..20)
        assert confirmed_blocks(known_confirmation) == Enum.to_list(@rollup_first_block..10)
        assert unconfirmed_blocks() == []
      end

      # The database has one batch of the blocks 1..20. The known confirmation holds
      # the blocks 11..20 of that batch, and its event is in the parent chain block 198.
      # The new event is in the parent chain block 200, and it points to the rollup
      # block 10. Thus the known confirmation of the upper blocks is the older one on
      # the parent chain.
      #
      # The new confirmation must cover the blocks 1..10, and the known confirmation
      # must keep the blocks 11..20.
      #
      # The lookup range of the new confirmation holds the log of the known
      # confirmation. That log points to the block 20, which is a block of the same
      # batch. Thus the discovery takes the block 21 as the first unconfirmed block of
      # the batch, which is above the top block of the new event. Therefore the
      # discovery finds no block for the new confirmation. It writes nothing for the new
      # event, and it returns `:confirmation_missed`.
      #
      # The test "confirms the blocks below an earlier confirmation of the same batch"
      # holds the same defect with an earlier event which the database does not know.
      # This test is the only one where the earlier confirmation of the same batch is a
      # known confirmation inside the discovery range.
      #
      # The second part of the test changes nothing in the database, thus the repeated
      # run must give `:ok`. The discovery gives `:confirmation_missed` again, and the
      # test fails on that assertion.
      #
      # The correction of the defect gives `:ok` and the blocks 1..10 in the first run.
      # Thus the person who removes the tag also removes the assertions of the first
      # part.
      @tag skip: "Defect: a new confirmation below a known confirmation of the same batch repeats the range"
      test "splits one batch when the known upper confirmation is older on the parent chain", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        batch = seed_batch(@rollup_first_block, 20, @commitment_l1_block)

        known_confirmation = insert_confirmation(@lower_confirmation_l1_block, @lower_confirmation_l1_timestamp)
        mark_confirmed(11..20, known_confirmation)

        new_confirmation_transaction_hash = to_string(transaction_hash())

        expect_discovery_of([
          build_send_root_updated_log(
            rollup_block_hash(batch, 20),
            to_string(known_confirmation.hash),
            @lower_confirmation_l1_block
          ),
          build_send_root_updated_log(
            rollup_block_hash(batch, 10),
            new_confirmation_transaction_hash,
            @confirmation_l1_block
          )
        ])

        assert :confirmation_missed == discover(json_rpc_named_arguments)

        assert Repo.get_by(LifecycleTransaction, hash: new_confirmation_transaction_hash) == nil
        assert confirmed_blocks(known_confirmation) == Enum.to_list(11..20)
        assert unconfirmed_blocks() == Enum.to_list(@rollup_first_block..10)

        assert :ok == discover(json_rpc_named_arguments)

        new_confirmation = Repo.get_by!(LifecycleTransaction, hash: new_confirmation_transaction_hash)
        assert new_confirmation.block_number == @confirmation_l1_block
        assert confirmed_blocks(new_confirmation) == Enum.to_list(@rollup_first_block..10)
        assert confirmed_blocks(known_confirmation) == Enum.to_list(11..20)
        assert unconfirmed_blocks() == []
      end
    end
  end
end
