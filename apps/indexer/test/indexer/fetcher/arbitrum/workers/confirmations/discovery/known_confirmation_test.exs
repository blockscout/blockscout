# SPDX-License-Identifier: LicenseRef-Blockscout
if Application.get_env(:explorer, :chain_type) == :arbitrum do
  defmodule Indexer.Fetcher.Arbitrum.Workers.Confirmations.Discovery.KnownConfirmationTest do
    use Indexer.Fetcher.Arbitrum.Workers.Confirmations.Discovery.TestCase

    # See `Indexer.Fetcher.Arbitrum.Workers.Confirmations.Discovery.TestCase` for
    # the conventions this suite of files follows.

    # The parent chain transaction of the event is in the database already, as a
    # lifecycle transaction. Thus the rollup blocks of this confirmation are linked
    # to it already.
    #
    # In this condition the discovery does not examine the rollup blocks one more
    # time. It only compares the block number and the timestamp of the known
    # transaction with the values from the event. A difference between them
    # can occur after a re-org.
    describe "perform/5 with an already known confirmation" do
      # The database has one batch with the rollup blocks 1..10, and no block of it
      # is confirmed. The lifecycle transaction of the confirmation is in the
      # database with the parent chain block 190.
      #
      # The event shows the same transaction in the parent chain block 200, because
      # a re-org moved it. Thus the discovery writes the new block number and the
      # new timestamp into the same record. The rollup blocks stay as they are, and
      # the discovery asks for no more logs.
      test "updates the confirmation transaction when its parent chain block changed", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        batch = seed_batch(@rollup_first_block, 10, @commitment_l1_block)

        existing_confirmation = insert_confirmation(@stale_confirmation_l1_block)

        expect_discovery(rollup_block_hash(batch, 10), to_string(existing_confirmation.hash))

        assert :ok == discover(json_rpc_named_arguments)

        updated_confirmation = Repo.get_by!(LifecycleTransaction, hash: existing_confirmation.hash)
        assert updated_confirmation.id == existing_confirmation.id
        assert updated_confirmation.block_number == @confirmation_l1_block
        assert DateTime.to_unix(updated_confirmation.timestamp) == @confirmation_l1_timestamp
        assert updated_confirmation.status == existing_confirmation.status

        assert unconfirmed_blocks() == Enum.to_list(@rollup_first_block..10)
      end

      # The lifecycle transaction of the confirmation is in the database. Its block
      # number and its timestamp are equal to the values in the event.
      #
      # The discovery finds no difference, thus it writes nothing and the result is
      # `:ok`. This is the usual result when the discovery reads the same parent
      # chain range one more time.
      test "leaves the confirmation transaction untouched when nothing changed", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        existing_confirmation = insert_confirmation(@confirmation_l1_block, @confirmation_l1_timestamp)

        expect_discovery(to_string(block_hash()), to_string(existing_confirmation.hash))

        assert :ok == discover(json_rpc_named_arguments)

        assert Repo.aggregate(LifecycleTransaction, :count) == 1

        kept_confirmation = Repo.get_by!(LifecycleTransaction, hash: existing_confirmation.hash)
        assert kept_confirmation.id == existing_confirmation.id
        assert kept_confirmation.block_number == @confirmation_l1_block
        assert DateTime.compare(kept_confirmation.timestamp, existing_confirmation.timestamp) == :eq
        assert kept_confirmation.status == existing_confirmation.status
      end

      # The lifecycle transaction of the confirmation is in the database with the parent
      # chain block 200. Its timestamp is not the timestamp of that block: the discovery
      # of an earlier run wrote another value, or the parent chain changed the timestamp
      # of the block.
      #
      # The event shows the same transaction in the same parent chain block 200. Thus
      # the discovery finds no difference of the block number, and it finds a difference
      # of the timestamp. Therefore it writes the new timestamp into the same record.
      # The identifier, the block number and the status of the record stay as they are.
      #
      # This test is not redundant. The test "updates the confirmation transaction when
      # its parent chain block changed" also writes the record again. In that test the
      # block number is different, and the timestamp comes with it. This test is the
      # only one where the timestamp alone gives the difference.
      #
      # The test seeds no batch, thus the count of the rows is exact and the event points
      # to a block hash outside the database. The discovery examines no rollup block for
      # a known confirmation.
      test "updates the confirmation transaction when only its timestamp changed", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        existing_confirmation = insert_confirmation(@confirmation_l1_block)

        expect_discovery(to_string(block_hash()), to_string(existing_confirmation.hash))

        assert :ok == discover(json_rpc_named_arguments)

        assert Repo.aggregate(LifecycleTransaction, :count) == 1

        updated_confirmation = Repo.get_by!(LifecycleTransaction, hash: existing_confirmation.hash)
        assert updated_confirmation.id == existing_confirmation.id
        assert updated_confirmation.block_number == @confirmation_l1_block
        assert DateTime.to_unix(updated_confirmation.timestamp) == @confirmation_l1_timestamp
        assert DateTime.compare(updated_confirmation.timestamp, existing_confirmation.timestamp) == :gt
        assert updated_confirmation.status == existing_confirmation.status
      end
    end
  end
end
