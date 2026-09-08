# SPDX-License-Identifier: LicenseRef-Blockscout
if Application.get_env(:explorer, :chain_type) == :arbitrum do
  defmodule Indexer.Fetcher.Arbitrum.Workers.Confirmations.Discovery.TwoKnownConfirmationsTest do
    use Indexer.Fetcher.Arbitrum.Workers.Confirmations.Discovery.TestCase

    # See `Indexer.Fetcher.Arbitrum.Workers.Confirmations.Discovery.TestCase` for
    # the conventions this suite of files follows.

    # The database can know both confirmations of the range already. Then the
    # discovery examines no rollup block, and it reads no more logs. It compares
    # the block number and the timestamp of each known transaction with the values
    # of its event. It writes only the transactions which show a
    # difference.
    describe "perform/5 with two already known confirmations" do
      # The database has one batch with the rollup blocks 1..10, and no block of it
      # is confirmed. Both confirmations of the range are in the database.
      #
      # A re-org moved the first confirmation. The database holds the parent chain
      # block 190, but the event of the confirmation is in the block 198. The
      # second confirmation shows the same values as its event.
      #
      # Thus the discovery writes the first transaction only. The second transaction
      # and all rollup blocks stay as they are.
      #
      # Both events point to a rollup block of the batch. A walk of the batch reads
      # the parent chain range of the commitment. The mock has no response for that
      # range, thus it fails. This is the proof that the discovery examines no rollup
      # block. With an unresolvable block hash, the walk ends quietly and the test
      # shows nothing.
      test "updates the confirmation which moved and keeps the other one", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        batch = seed_batch(@rollup_first_block, 10, @commitment_l1_block)

        moved_confirmation = insert_confirmation(@stale_confirmation_l1_block)
        kept_confirmation = insert_confirmation(@confirmation_l1_block, @confirmation_l1_timestamp)

        expect_discovery_of([
          build_send_root_updated_log(
            rollup_block_hash(batch, 5),
            to_string(moved_confirmation.hash),
            @lower_confirmation_l1_block
          ),
          build_send_root_updated_log(
            rollup_block_hash(batch, 10),
            to_string(kept_confirmation.hash),
            @confirmation_l1_block
          )
        ])

        assert :ok == discover(json_rpc_named_arguments)

        updated_confirmation = Repo.get_by!(LifecycleTransaction, hash: moved_confirmation.hash)
        assert updated_confirmation.id == moved_confirmation.id
        assert updated_confirmation.block_number == @lower_confirmation_l1_block
        assert DateTime.to_unix(updated_confirmation.timestamp) == @lower_confirmation_l1_timestamp

        untouched_confirmation = Repo.get_by!(LifecycleTransaction, hash: kept_confirmation.hash)
        assert untouched_confirmation.id == kept_confirmation.id
        assert untouched_confirmation.block_number == @confirmation_l1_block
        assert DateTime.compare(untouched_confirmation.timestamp, kept_confirmation.timestamp) == :eq

        assert unconfirmed_blocks() == Enum.to_list(@rollup_first_block..10)
      end

      # Both confirmations of the range are in the database, and the values of both
      # are equal to the values of their events. When the discovery reads the same
      # parent chain range one more time, it finds this condition. This condition is
      # the usual state of a production chain. Every iteration of the discovery reads
      # a range which overlaps the previous one.
      #
      # The discovery finds no difference. Thus it writes nothing, and the result
      # is `:ok`.
      #
      # This test is not redundant. The test "updates the confirmation which moved
      # and keeps the other one" runs the same branches. But this test is the only
      # one of the groups with two events which counts the rows of
      # `LifecycleTransaction`.
      #
      # The count is exact here, because the test seeds no batch. Thus the count
      # shows that neither of the two known events adds a row. The other test seeds a
      # batch, and `seed_batch/3` leaves lifecycle transactions of its own. Thus a
      # count there gives no information.
      #
      # For the same reason the events here point to block hashes outside the
      # database. A batch breaks the exact count. The other test already shows that
      # the discovery walks no batch.
      test "leaves both confirmation transactions untouched when nothing changed", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        lower_confirmation = insert_confirmation(@lower_confirmation_l1_block, @lower_confirmation_l1_timestamp)
        upper_confirmation = insert_confirmation(@confirmation_l1_block, @confirmation_l1_timestamp)

        expect_discovery_of([
          build_send_root_updated_log(
            to_string(block_hash()),
            to_string(lower_confirmation.hash),
            @lower_confirmation_l1_block
          ),
          build_send_root_updated_log(
            to_string(block_hash()),
            to_string(upper_confirmation.hash),
            @confirmation_l1_block
          )
        ])

        assert :ok == discover(json_rpc_named_arguments)

        # This test seeds no batch. Thus the database holds the two confirmations
        # only.
        assert Repo.aggregate(LifecycleTransaction, :count) == 2

        kept_lower_confirmation = Repo.get_by!(LifecycleTransaction, hash: lower_confirmation.hash)
        assert kept_lower_confirmation.id == lower_confirmation.id
        assert kept_lower_confirmation.block_number == @lower_confirmation_l1_block
        assert DateTime.compare(kept_lower_confirmation.timestamp, lower_confirmation.timestamp) == :eq
        assert kept_lower_confirmation.status == lower_confirmation.status

        kept_upper_confirmation = Repo.get_by!(LifecycleTransaction, hash: upper_confirmation.hash)
        assert kept_upper_confirmation.id == upper_confirmation.id
        assert kept_upper_confirmation.block_number == @confirmation_l1_block
        assert DateTime.compare(kept_upper_confirmation.timestamp, upper_confirmation.timestamp) == :eq
        assert kept_upper_confirmation.status == upper_confirmation.status
      end

      # Both confirmations of the range are in the database, and both events are in
      # the same parent chain block. One block of the parent chain can hold two calls
      # which confirm a node. Then the parent chain gives this state.
      #
      # The values of both confirmations are equal to the values of their events. Thus
      # the discovery writes nothing, and the result is `:ok`.
      #
      # This test is not redundant. It is the only test of this group which puts two
      # events into one parent chain block. One parent chain block can hold two
      # transactions which confirm a node.
      #
      # As in the test before, the events point to block hashes outside the database,
      # and the test seeds no batch. Thus the count of the rows is exact.
      #
      # The two hashes are different, because each event confirms another node. The
      # discovery reads neither of them. It takes the hash of a rollup block only for a
      # confirmation which the database does not know.
      test "keeps both known confirmations when the two events are in one parent chain block", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        first_confirmation = insert_confirmation(@confirmation_l1_block, @confirmation_l1_timestamp)
        second_confirmation = insert_confirmation(@confirmation_l1_block, @confirmation_l1_timestamp)

        expect_discovery_of([
          build_send_root_updated_log(
            to_string(block_hash()),
            to_string(first_confirmation.hash),
            @confirmation_l1_block
          ),
          build_send_root_updated_log(
            to_string(block_hash()),
            to_string(second_confirmation.hash),
            @confirmation_l1_block,
            log_index: 1,
            transaction_index: 1
          )
        ])

        assert :ok == discover(json_rpc_named_arguments)

        # This test seeds no batch. Thus the database holds the two confirmations
        # only.
        assert Repo.aggregate(LifecycleTransaction, :count) == 2

        kept_first_confirmation = Repo.get_by!(LifecycleTransaction, hash: first_confirmation.hash)
        assert kept_first_confirmation.id == first_confirmation.id
        assert kept_first_confirmation.block_number == @confirmation_l1_block
        assert DateTime.compare(kept_first_confirmation.timestamp, first_confirmation.timestamp) == :eq

        kept_second_confirmation = Repo.get_by!(LifecycleTransaction, hash: second_confirmation.hash)
        assert kept_second_confirmation.id == second_confirmation.id
        assert kept_second_confirmation.block_number == @confirmation_l1_block
        assert DateTime.compare(kept_second_confirmation.timestamp, second_confirmation.timestamp) == :eq
      end

      # The database has two batches: the blocks 1..10 and the blocks 11..20. The first
      # known confirmation holds the blocks 1..10, and the second one holds the blocks
      # 11..20. A re-org moved both transactions: the database holds the parent chain
      # block 190 for each of them, and their events are in the blocks 198 and 200.
      #
      # Thus the discovery writes both records again with their new block numbers and
      # their new timestamps. The identifiers, the statuses and the rollup blocks of the
      # two confirmations stay as they are.
      #
      # This test is not redundant. The test "updates the confirmation which moved and
      # keeps the other one" writes one record of the two. This test is the only one
      # where one run writes both known transactions. It is also the only test of this
      # group which holds the rollup blocks of the two confirmations. Thus it shows that
      # a run which moves two transactions does not move a rollup block.
      test "updates both confirmations which moved", %{json_rpc_named_arguments: json_rpc_named_arguments} do
        previous_batch = seed_batch(@rollup_first_block, 10, @previous_commitment_l1_block)
        batch = seed_batch(11, 20, @commitment_l1_block)

        lower_confirmation = insert_confirmation(@stale_confirmation_l1_block)
        mark_confirmed(@rollup_first_block..10, lower_confirmation)

        upper_confirmation = insert_confirmation(@stale_confirmation_l1_block)
        mark_confirmed(11..20, upper_confirmation)

        expect_discovery_of([
          build_send_root_updated_log(
            rollup_block_hash(previous_batch, 10),
            to_string(lower_confirmation.hash),
            @lower_confirmation_l1_block
          ),
          build_send_root_updated_log(
            rollup_block_hash(batch, 20),
            to_string(upper_confirmation.hash),
            @confirmation_l1_block
          )
        ])

        assert :ok == discover(json_rpc_named_arguments)

        updated_lower_confirmation = Repo.get_by!(LifecycleTransaction, hash: lower_confirmation.hash)
        assert updated_lower_confirmation.id == lower_confirmation.id
        assert updated_lower_confirmation.block_number == @lower_confirmation_l1_block
        assert DateTime.to_unix(updated_lower_confirmation.timestamp) == @lower_confirmation_l1_timestamp
        assert updated_lower_confirmation.status == lower_confirmation.status
        assert confirmed_blocks(updated_lower_confirmation) == Enum.to_list(@rollup_first_block..10)

        updated_upper_confirmation = Repo.get_by!(LifecycleTransaction, hash: upper_confirmation.hash)
        assert updated_upper_confirmation.id == upper_confirmation.id
        assert updated_upper_confirmation.block_number == @confirmation_l1_block
        assert DateTime.to_unix(updated_upper_confirmation.timestamp) == @confirmation_l1_timestamp
        assert updated_upper_confirmation.status == upper_confirmation.status
        assert confirmed_blocks(updated_upper_confirmation) == Enum.to_list(11..20)

        assert unconfirmed_blocks() == []
      end
    end
  end
end
