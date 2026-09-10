# SPDX-License-Identifier: LicenseRef-Blockscout
if Application.get_env(:explorer, :chain_type) == :arbitrum do
  defmodule Indexer.Fetcher.Arbitrum.Workers.Confirmations.Discovery.TwoNewConfirmationsSameBlockOrInvertedTest do
    use Indexer.Fetcher.Arbitrum.Workers.Confirmations.Discovery.TestCase

    # See `Indexer.Fetcher.Arbitrum.Workers.Confirmations.Discovery.TestCase` for
    # the conventions this suite of files follows.

    # The lookup range of a confirmation ends one block before the parent chain
    # block of that confirmation. So the range holds no log of another confirmation
    # of the same parent chain block. It also holds no log of a confirmation of a
    # newer block.
    #
    # This group holds the scenarios where the parent chain gives such a pair:
    #   - both events are in one parent chain block, which happens when one block
    #     holds two transactions which confirm a node
    #   - both events are in one parent chain transaction, which happens when one
    #     transaction calls the outbox two times
    #   - the events are in the inverted order: the older parent chain block holds
    #     the confirmation of the higher rollup blocks
    #
    # In each of these scenarios the walk of a confirmation does not find the
    # boundary which the other confirmation of the same run gives. So the two
    # confirmations claim the same rollup blocks, or one of them takes the blocks of
    # the other. Every test of this group carries the tag of a defect and holds the
    # correct result.
    describe "perform/5 with two new confirmations in one parent chain block or in the inverted order" do
      # Both events are new, and both events are in the same parent chain block. One
      # parent chain block can hold two transactions which confirm a node. Then the
      # parent chain gives this state.
      #
      # The database has one batch with the rollup blocks 1..20. No block of it is
      # confirmed. The lower event points to the rollup block 10. The upper event
      # points to the rollup block 20.
      #
      # The lower confirmation must cover the blocks 1..10, and the upper
      # confirmation must cover the blocks 11..20.
      #
      # The lookup range of a confirmation ends one block before the parent chain
      # block of that confirmation. So the lookup range of the upper confirmation
      # holds no log of the lower confirmation. The walk continues to the first
      # block of the batch. The lower confirmation then holds the blocks 1..10, and
      # the upper confirmation holds the blocks 1..20. The blocks 1..10 belong to
      # both. One import gets two rows of each of those blocks, and the database
      # stops the import with a cardinality violation.
      #
      # The test "splits one batch between the two confirmations of the inverted
      # order in the same parent chain block" holds the other order of the two logs.
      # The discovery does not read the log index, and it does not read the
      # transaction index. So the two runs are the same. The two tests hold the two
      # orders of the logs. So a correction which reads the log index must give the
      # correct pair of transactions in each test.
      @tag skip: "Defect: two new confirmations in the same parent chain block"
      test "splits one batch between the two confirmations of the same parent chain block", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        batch = seed_batch(@rollup_first_block, 20, @commitment_l1_block)

        lower_confirmation_transaction_hash = to_string(transaction_hash())
        upper_confirmation_transaction_hash = to_string(transaction_hash())

        lower_confirmation_log =
          build_send_root_updated_log(
            rollup_block_hash(batch, 10),
            lower_confirmation_transaction_hash,
            @confirmation_l1_block
          )

        upper_confirmation_log =
          build_send_root_updated_log(
            rollup_block_hash(batch, 20),
            upper_confirmation_transaction_hash,
            @confirmation_l1_block,
            log_index: 1,
            transaction_index: 1
          )

        expect_discovery_of([lower_confirmation_log, upper_confirmation_log])

        assert :ok == discover(json_rpc_named_arguments)

        lower_confirmation = Repo.get_by!(LifecycleTransaction, hash: lower_confirmation_transaction_hash)
        upper_confirmation = Repo.get_by!(LifecycleTransaction, hash: upper_confirmation_transaction_hash)

        assert lower_confirmation.id != upper_confirmation.id
        assert lower_confirmation.block_number == @confirmation_l1_block
        assert upper_confirmation.block_number == @confirmation_l1_block

        assert confirmed_blocks(lower_confirmation) == Enum.to_list(@rollup_first_block..10)
        assert confirmed_blocks(upper_confirmation) == Enum.to_list(11..20)
        assert unconfirmed_blocks() == []
      end

      # Both events are new, and both events are in the same parent chain block. The
      # log with the index 0 points to the higher rollup block. So the pair holds the
      # inverted order in one parent chain block. A chain which confirms two nodes
      # in one parent chain block can give this order.
      #
      # The database has one batch with the rollup blocks 1..20. No block of it is
      # confirmed. The log with the index 0 points to the rollup block 20. The log with
      # the index 1 points to the rollup block 10.
      #
      # The confirmation of the block 10 must cover the blocks 1..10, and the
      # confirmation of the block 20 must cover the blocks 11..20. So the transaction
      # of the log with the index 0 takes the upper blocks. The transaction of the log
      # with the index 1 takes the lower blocks. The test "splits one batch between the
      # two confirmations of the same parent chain block" holds the other order of the
      # two logs. In that test the log with the index 0 takes the lower blocks. The link
      # between the log order and the transactions is what this test holds and no other
      # test holds.
      #
      # The discovery does not read the log index, and it does not read the transaction
      # index. It sorts the confirmations by the number of the rollup block. So this
      # run is the same as the run of that other test.
      #
      # The lookup range of a confirmation ends one block before the parent chain block
      # of that confirmation. So no lookup range holds the log of the other
      # confirmation. Each walk continues to the first block of the batch. So the
      # blocks 1..10 belong to both confirmations. One import gets two rows of each of
      # those blocks, and the database stops the import with a cardinality violation.
      @tag skip: "Defect: two new confirmations in the same parent chain block"
      test "splits one batch between the two confirmations of the inverted order in the same parent chain block", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        batch = seed_batch(@rollup_first_block, 20, @commitment_l1_block)

        upper_blocks_transaction_hash = to_string(transaction_hash())
        lower_blocks_transaction_hash = to_string(transaction_hash())

        # The log with the index 0 holds the confirmation of the upper blocks. The log
        # with the index 1 holds the confirmation of the lower blocks.
        upper_blocks_confirmation_log =
          build_send_root_updated_log(
            rollup_block_hash(batch, 20),
            upper_blocks_transaction_hash,
            @confirmation_l1_block
          )

        lower_blocks_confirmation_log =
          build_send_root_updated_log(
            rollup_block_hash(batch, 10),
            lower_blocks_transaction_hash,
            @confirmation_l1_block,
            log_index: 1,
            transaction_index: 1
          )

        expect_discovery_of([upper_blocks_confirmation_log, lower_blocks_confirmation_log])

        assert :ok == discover(json_rpc_named_arguments)

        upper_blocks_confirmation = Repo.get_by!(LifecycleTransaction, hash: upper_blocks_transaction_hash)
        lower_blocks_confirmation = Repo.get_by!(LifecycleTransaction, hash: lower_blocks_transaction_hash)

        assert upper_blocks_confirmation.id != lower_blocks_confirmation.id
        assert upper_blocks_confirmation.block_number == @confirmation_l1_block
        assert lower_blocks_confirmation.block_number == @confirmation_l1_block

        assert confirmed_blocks(lower_blocks_confirmation) == Enum.to_list(@rollup_first_block..10)
        assert confirmed_blocks(upper_blocks_confirmation) == Enum.to_list(11..20)
        assert unconfirmed_blocks() == []
      end

      # Both events are new, and both events are in the same parent chain block. The
      # database has two batches: the blocks 1..10 and the blocks 11..20. No block of
      # them is confirmed. The lower event points to the rollup block 5, which is in
      # the middle of the first batch. The upper event points to the rollup block 20,
      # which is the last block of the second batch.
      #
      # The lower confirmation must cover the blocks 1..5, and the upper confirmation
      # must cover the blocks 6..20.
      #
      # The lookup range of the upper confirmation ends one block before the parent
      # chain block of that confirmation. So it holds no log of the lower
      # confirmation. The walk reaches the first block of the second batch, and it
      # moves one batch down. The database shows no confirmed block in the first
      # batch. So the walk takes the whole first batch, and the upper confirmation
      # gets the blocks 1..20. The blocks 1..5 belong to both confirmations. One
      # import gets two rows of each of those blocks, and the database stops the
      # import with a cardinality violation. The result is neither `:ok` nor
      # `:confirmation_missed`.
      #
      # The test "splits one batch between the two confirmations of the same parent
      # chain block" holds the same pair of events over a single batch. This test is
      # the only one where the walk of the upper confirmation crosses a batch
      # boundary. The walk then takes the whole batch of the lower confirmation. The
      # position of the lower event within its batch does not change the result. The
      # crossing of the boundary gives the rows of both confirmations.
      @tag skip: "Defect: two new confirmations in the same parent chain block"
      test "splits two batches between the two confirmations of the same parent chain block", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        previous_batch = seed_batch(@rollup_first_block, 10, @previous_commitment_l1_block)
        batch = seed_batch(11, 20, @commitment_l1_block)

        lower_confirmation_transaction_hash = to_string(transaction_hash())
        upper_confirmation_transaction_hash = to_string(transaction_hash())

        expect_discovery_of([
          build_send_root_updated_log(
            rollup_block_hash(previous_batch, 5),
            lower_confirmation_transaction_hash,
            @confirmation_l1_block
          ),
          build_send_root_updated_log(
            rollup_block_hash(batch, 20),
            upper_confirmation_transaction_hash,
            @confirmation_l1_block,
            log_index: 1,
            transaction_index: 1
          )
        ])

        assert :ok == discover(json_rpc_named_arguments)

        lower_confirmation = Repo.get_by!(LifecycleTransaction, hash: lower_confirmation_transaction_hash)
        upper_confirmation = Repo.get_by!(LifecycleTransaction, hash: upper_confirmation_transaction_hash)

        assert lower_confirmation.id != upper_confirmation.id
        assert lower_confirmation.block_number == @confirmation_l1_block
        assert upper_confirmation.block_number == @confirmation_l1_block

        assert confirmed_blocks(lower_confirmation) == Enum.to_list(@rollup_first_block..5)
        assert confirmed_blocks(upper_confirmation) == Enum.to_list(6..20)
        assert unconfirmed_blocks() == []
      end

      # Both events are new, and both events are in the same parent chain
      # transaction. One transaction can call the outbox two times. Then the parent
      # chain gives this state. The scenario of two events in the same parent chain
      # block is wider. The two events of this test also have the same transaction
      # hash.
      #
      # This test belongs to the two-new-confirmations group because the parent
      # chain gives two new events. Its result holds one confirmation, and not two,
      # because the database holds one confirmation per parent chain transaction.
      #
      # The database has one batch with the rollup blocks 1..20. No block of it is
      # confirmed. The lower event points to the rollup block 10. The upper event
      # points to the rollup block 20.
      #
      # The database holds one confirmation per parent chain transaction. So the two
      # events must give one confirmation, and that confirmation must hold the
      # rollup blocks 1..20.
      #
      # The discovery examines the two events one after another. It finds no earlier
      # confirmation for each of the two events. The lookup range ends one block
      # before the parent chain block of the events. So the lower event gives the
      # blocks 1..10, and the upper event gives the blocks 1..20. One import gets
      # two rows of each block of 1..10, and the database stops the import with a
      # cardinality violation. The two rows of a block hold the same confirmation.
      #
      # The second part of the test changes nothing in the database. It examines the
      # same parent chain range again, and the database knows the transaction of the
      # two logs by then. So the discovery examines no rollup block, and it keeps
      # one record with its blocks. This test is the only one that holds two logs of
      # one known transaction in one range. Before this part runs, the first run
      # must succeed. So the part waits for the correction of the defect.
      @tag skip: "Defect: two new confirmations in the same parent chain transaction"
      test "gives all rollup blocks to one confirmation when both events are in the same transaction", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        batch = seed_batch(@rollup_first_block, 20, @commitment_l1_block)

        confirmation_transaction_hash = to_string(transaction_hash())

        lower_confirmation_log =
          build_send_root_updated_log(
            rollup_block_hash(batch, 10),
            confirmation_transaction_hash,
            @confirmation_l1_block
          )

        upper_confirmation_log =
          build_send_root_updated_log(
            rollup_block_hash(batch, 20),
            confirmation_transaction_hash,
            @confirmation_l1_block,
            log_index: 1
          )

        expect_discovery_of([lower_confirmation_log, upper_confirmation_log])

        assert :ok == discover(json_rpc_named_arguments)

        confirmation = Repo.get_by!(LifecycleTransaction, hash: confirmation_transaction_hash)
        assert confirmation.block_number == @confirmation_l1_block
        assert DateTime.to_unix(confirmation.timestamp) == @confirmation_l1_timestamp

        assert confirmed_blocks(confirmation) == Enum.to_list(@rollup_first_block..20)
        assert unconfirmed_blocks() == []

        assert :ok == discover(json_rpc_named_arguments)

        kept_confirmation = Repo.get_by!(LifecycleTransaction, hash: confirmation_transaction_hash)
        assert kept_confirmation.id == confirmation.id
        assert kept_confirmation.block_number == @confirmation_l1_block
        assert DateTime.compare(kept_confirmation.timestamp, confirmation.timestamp) == :eq

        assert confirmed_blocks(kept_confirmation) == Enum.to_list(@rollup_first_block..20)
        assert unconfirmed_blocks() == []
      end

      # The database has two batches: the blocks 1..10 and the blocks 11..20. No
      # block is confirmed.
      #
      # Both events are new. The event of the older parent chain block points to the
      # rollup block 20. The event of the newer parent chain block points to the
      # rollup block 10. So the newer transaction confirms the lower rollup blocks.
      # The HPP mainnet, which is an Arbitrum AnyTrust chain, holds such a pair of
      # confirmations, 3 parent chain blocks apart.
      #
      # The confirmation of the block 10 must cover the blocks 1..10, and the
      # confirmation of the block 20 must cover the blocks 11..20.
      #
      # The lookup range of a confirmation ends one block before the parent chain
      # block of that confirmation. The confirmation of the block 20 is in the older
      # parent chain block. So its lookup range holds no log of the confirmation of
      # the block 10. The walk of the confirmation of the block 20 continues to the
      # first block of the chain. Each of the two confirmations then holds the
      # blocks 1..10. One import gets two rows of each block of 1..10, and the
      # database stops the import with a cardinality violation.
      @tag skip: "Defect: two new confirmations in the inverted order"
      test "splits the batches between the two confirmations of the inverted order", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        previous_batch = seed_batch(@rollup_first_block, 10, @previous_commitment_l1_block)
        batch = seed_batch(11, 20, @commitment_l1_block)

        lower_blocks_transaction_hash = to_string(transaction_hash())
        upper_blocks_transaction_hash = to_string(transaction_hash())

        # The parent chain holds the confirmation of the upper blocks in the older
        # block, and the confirmation of the lower blocks in the newer block.
        upper_blocks_confirmation_log =
          build_send_root_updated_log(
            rollup_block_hash(batch, 20),
            upper_blocks_transaction_hash,
            @lower_confirmation_l1_block
          )

        lower_blocks_confirmation_log =
          build_send_root_updated_log(
            rollup_block_hash(previous_batch, 10),
            lower_blocks_transaction_hash,
            @confirmation_l1_block
          )

        expect_discovery_of([upper_blocks_confirmation_log, lower_blocks_confirmation_log])

        assert :ok == discover(json_rpc_named_arguments)

        upper_blocks_confirmation = Repo.get_by!(LifecycleTransaction, hash: upper_blocks_transaction_hash)
        assert upper_blocks_confirmation.block_number == @lower_confirmation_l1_block
        assert DateTime.to_unix(upper_blocks_confirmation.timestamp) == @lower_confirmation_l1_timestamp

        lower_blocks_confirmation = Repo.get_by!(LifecycleTransaction, hash: lower_blocks_transaction_hash)
        assert lower_blocks_confirmation.block_number == @confirmation_l1_block
        assert DateTime.to_unix(lower_blocks_confirmation.timestamp) == @confirmation_l1_timestamp

        assert confirmed_blocks(lower_blocks_confirmation) == Enum.to_list(@rollup_first_block..10)
        assert confirmed_blocks(upper_blocks_confirmation) == Enum.to_list(11..20)
        assert unconfirmed_blocks() == []
      end

      # The database has one batch of the blocks 1..20. No block of it is confirmed.
      #
      # Both events are new. The event of the older parent chain block points to the
      # rollup block 20. The event of the newer parent chain block points to the
      # rollup block 10. So the newer transaction confirms the lower rollup blocks.
      # The HPP mainnet, which is an Arbitrum AnyTrust chain, holds such a pair of
      # confirmations.
      #
      # The confirmation of the block 10 must cover the blocks 1..10, and the
      # confirmation of the block 20 must cover the blocks 11..20.
      #
      # The discovery handles the confirmations in the order of their rollup blocks.
      # So it handles the confirmation of the block 10 first. The lookup range of
      # that confirmation holds the log of the confirmation of the block 20. That
      # log points to a block of the same batch. So the discovery takes the block 21
      # as the first unconfirmed block of the batch. The block 21 is higher than the
      # block 10. So the confirmation of the block 10 gets no rollup block.
      #
      # After that the confirmation of the block 20 finds no earlier log in its own
      # lookup range, and it takes the full batch. So the run writes one
      # confirmation of the two, and it returns `:confirmation_missed`.
      #
      # The test "splits the batches between the two confirmations of the inverted
      # order" holds the same pair of events over two batches. In that test, the
      # import stops with a cardinality violation, because the two confirmations
      # hold the same blocks. This test is the only one where the inverted order
      # gives one confirmation of the whole batch and loses the other one.
      #
      # The second part of the test changes nothing in the database. The database
      # holds the whole batch already. So the indexer has nothing to add. As a
      # result, the repeated run of the same parent chain range must give `:ok` and
      # the same pair of confirmations. The discovery gives `:confirmation_missed`
      # again, because the full batch belongs to the confirmation of the block 20
      # now. So the historical discovery reads this range again and again.
      #
      # The correction of the defect gives the correct pair in the first run. So the
      # person who removes the tag also removes the assertions of the first part.
      @tag skip: "Defect: two new confirmations of the inverted order in one batch"
      test "splits one batch between the two confirmations of the inverted order in two parent chain blocks", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        batch = seed_batch(@rollup_first_block, 20, @commitment_l1_block)

        lower_blocks_transaction_hash = to_string(transaction_hash())
        upper_blocks_transaction_hash = to_string(transaction_hash())

        # The parent chain holds the confirmation of the upper blocks in the older
        # block, and the confirmation of the lower blocks in the newer block.
        expect_discovery_of([
          build_send_root_updated_log(
            rollup_block_hash(batch, 20),
            upper_blocks_transaction_hash,
            @lower_confirmation_l1_block
          ),
          build_send_root_updated_log(
            rollup_block_hash(batch, 10),
            lower_blocks_transaction_hash,
            @confirmation_l1_block
          )
        ])

        assert :confirmation_missed == discover(json_rpc_named_arguments)

        upper_blocks_confirmation = Repo.get_by!(LifecycleTransaction, hash: upper_blocks_transaction_hash)
        assert Repo.get_by(LifecycleTransaction, hash: lower_blocks_transaction_hash) == nil
        assert confirmed_blocks(upper_blocks_confirmation) == Enum.to_list(@rollup_first_block..20)
        assert unconfirmed_blocks() == []

        assert :ok == discover(json_rpc_named_arguments)

        lower_blocks_confirmation = Repo.get_by!(LifecycleTransaction, hash: lower_blocks_transaction_hash)
        assert lower_blocks_confirmation.block_number == @confirmation_l1_block
        assert confirmed_blocks(lower_blocks_confirmation) == Enum.to_list(@rollup_first_block..10)
        assert confirmed_blocks(upper_blocks_confirmation) == Enum.to_list(11..20)
        assert unconfirmed_blocks() == []
      end
    end
  end
end
