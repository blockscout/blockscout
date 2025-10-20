defmodule Explorer.Migrator.CeloAggregatedElectionRewardsTest do
  use Explorer.DataCase, async: false

  use Utils.CompileTimeEnvHelper,
    chain_type: [:explorer, :chain_type]

  if @chain_type == :celo do
    alias Explorer.Chain.Celo.{AggregatedElectionReward, Epoch}
    alias Explorer.Migrator.{CeloAggregatedElectionRewards, MigrationStatus}
    alias Explorer.Repo

    import Ecto.Query

    describe "celo_aggregated_election_rewards migration" do
      setup do
        # Clean up migration status before each test
        Repo.delete_all(MigrationStatus)
        :ok
      end

      test "does not fail when there are no epochs" do
        # Ensure no epochs exist
        assert Repo.aggregate(Epoch, :count) == 0

        # Run migration
        assert MigrationStatus.get_status("celo_aggregated_election_rewards") == nil
        {:ok, _} = CeloAggregatedElectionRewards.start_link([])

        # Wait for migration to complete
        Process.sleep(500)

        # Verify migration completed successfully
        assert MigrationStatus.get_status("celo_aggregated_election_rewards") == "completed"

        # Verify no aggregated rewards were created
        assert Repo.aggregate(AggregatedElectionReward, :count) == 0
      end

      test "skips epochs without end_processing_block_hash (unfinalized epochs)" do
        # Create finalized epoch
        finalized_epoch = insert(:celo_epoch, number: 100, end_processing_block_hash: insert(:block).hash)

        # Create unfinalized epoch (no end_processing_block_hash)
        _unfinalized_epoch = insert(:celo_epoch, number: 101, end_processing_block_hash: nil)

        # Create addresses for the rewards
        account_address = insert(:address)
        associated_address = insert(:address)

        # Add rewards for finalized epoch
        insert(:celo_election_reward,
          epoch_number: finalized_epoch.number,
          type: :voter,
          amount: 1000,
          account_address_hash: account_address.hash,
          associated_account_address_hash: associated_address.hash
        )

        # Add rewards for unfinalized epoch
        insert(:celo_election_reward,
          epoch_number: 101,
          type: :voter,
          amount: 2000,
          account_address_hash: account_address.hash,
          associated_account_address_hash: associated_address.hash
        )

        # Run migration
        {:ok, _} = CeloAggregatedElectionRewards.start_link([])
        Process.sleep(500)

        # Verify only finalized epoch was processed
        aggregated_rewards = Repo.all(AggregatedElectionReward)
        # Only 1 reward type (voter) has data, so only 1 aggregate is saved (no zeros)
        assert length(aggregated_rewards) == 1

        epoch_numbers = Enum.map(aggregated_rewards, & &1.epoch_number) |> Enum.uniq()
        assert epoch_numbers == [100]
      end

      test "backfills aggregated rewards for a single epoch with all reward types" do
        epoch = insert(:celo_epoch, number: 42, end_processing_block_hash: insert(:block).hash)

        # Create addresses for the rewards
        account1 = insert(:address)
        account2 = insert(:address)
        associated1 = insert(:address)
        associated2 = insert(:address)

        # Insert rewards for all types
        insert(:celo_election_reward,
          epoch_number: epoch.number,
          type: :voter,
          amount: 1000,
          account_address_hash: account1.hash,
          associated_account_address_hash: associated1.hash
        )

        insert(:celo_election_reward,
          epoch_number: epoch.number,
          type: :voter,
          amount: 1500,
          account_address_hash: account2.hash,
          associated_account_address_hash: associated1.hash
        )

        insert(:celo_election_reward,
          epoch_number: epoch.number,
          type: :validator,
          amount: 2000,
          account_address_hash: account1.hash,
          associated_account_address_hash: associated1.hash
        )

        insert(:celo_election_reward,
          epoch_number: epoch.number,
          type: :group,
          amount: 3000,
          account_address_hash: account1.hash,
          associated_account_address_hash: associated1.hash
        )

        insert(:celo_election_reward,
          epoch_number: epoch.number,
          type: :group,
          amount: 3500,
          account_address_hash: account1.hash,
          associated_account_address_hash: associated2.hash
        )

        insert(:celo_election_reward,
          epoch_number: epoch.number,
          type: :group,
          amount: 4000,
          account_address_hash: account2.hash,
          associated_account_address_hash: associated1.hash
        )

        insert(:celo_election_reward,
          epoch_number: epoch.number,
          type: :delegated_payment,
          amount: 500,
          account_address_hash: account1.hash,
          associated_account_address_hash: associated1.hash
        )

        # Ensure migration has not run yet
        assert MigrationStatus.get_status("celo_aggregated_election_rewards") == nil

        # Run migration
        {:ok, _} = CeloAggregatedElectionRewards.start_link([])

        # Wait for migration to complete
        Process.sleep(500)

        # Verify aggregated rewards were created correctly
        aggregated_rewards =
          from(aer in AggregatedElectionReward,
            where: aer.epoch_number == ^epoch.number,
            order_by: [asc: aer.type]
          )
          |> Repo.all()

        assert length(aggregated_rewards) == 4

        # Check voter rewards
        voter_reward = Enum.find(aggregated_rewards, &(&1.type == :voter))
        assert voter_reward.count == 2
        assert Decimal.to_integer(voter_reward.sum.value) == 2500

        # Check validator rewards
        validator_reward = Enum.find(aggregated_rewards, &(&1.type == :validator))
        assert validator_reward.count == 1
        assert Decimal.to_integer(validator_reward.sum.value) == 2000

        # Check group rewards
        group_reward = Enum.find(aggregated_rewards, &(&1.type == :group))
        assert group_reward.count == 3
        assert Decimal.to_integer(group_reward.sum.value) == 10500

        # Check delegated_payment rewards
        delegated_reward = Enum.find(aggregated_rewards, &(&1.type == :delegated_payment))
        assert delegated_reward.count == 1
        assert Decimal.to_integer(delegated_reward.sum.value) == 500

        # Confirm migration status is completed
        assert MigrationStatus.get_status("celo_aggregated_election_rewards") == "completed"
      end

      test "only saves reward types with data (no zero values)" do
        epoch = insert(:celo_epoch, number: 50, end_processing_block_hash: insert(:block).hash)

        # Create addresses
        account = insert(:address)
        associated = insert(:address)

        # Only insert voter rewards, leaving other types empty
        insert(:celo_election_reward,
          epoch_number: epoch.number,
          type: :voter,
          amount: 5000,
          account_address_hash: account.hash,
          associated_account_address_hash: associated.hash
        )

        # Run migration
        {:ok, _} = CeloAggregatedElectionRewards.start_link([])
        Process.sleep(500)

        # Verify only reward types with data are saved (no zero values)
        aggregated_rewards =
          from(aer in AggregatedElectionReward,
            where: aer.epoch_number == ^epoch.number,
            order_by: [asc: aer.type]
          )
          |> Repo.all()

        # Only voter type has data, so only 1 aggregate is saved
        assert length(aggregated_rewards) == 1

        # Check voter has data
        voter_reward = Enum.at(aggregated_rewards, 0)
        assert voter_reward.type == :voter
        assert voter_reward.count == 1
        assert Decimal.to_integer(voter_reward.sum.value) == 5000

        # Verify other types are NOT saved (no zero-value entries)
        for type <- [:validator, :group, :delegated_payment] do
          reward = Enum.find(aggregated_rewards, &(&1.type == type))
          assert reward == nil
        end
      end

      test "backfills aggregated rewards for multiple epochs" do
        # Create multiple finalized epochs
        epoch1 = insert(:celo_epoch, number: 10, end_processing_block_hash: insert(:block).hash)
        epoch2 = insert(:celo_epoch, number: 11, end_processing_block_hash: insert(:block).hash)
        epoch3 = insert(:celo_epoch, number: 12, end_processing_block_hash: insert(:block).hash)

        # Create addresses
        account = insert(:address)
        associated = insert(:address)

        # Add rewards for epoch 1
        insert(:celo_election_reward,
          epoch_number: epoch1.number,
          type: :voter,
          amount: 100,
          account_address_hash: account.hash,
          associated_account_address_hash: associated.hash
        )

        insert(:celo_election_reward,
          epoch_number: epoch1.number,
          type: :validator,
          amount: 200,
          account_address_hash: account.hash,
          associated_account_address_hash: associated.hash
        )

        # Add rewards for epoch 2
        insert(:celo_election_reward,
          epoch_number: epoch2.number,
          type: :group,
          amount: 300,
          account_address_hash: account.hash,
          associated_account_address_hash: associated.hash
        )

        # Add rewards for epoch 3
        account2 = insert(:address)

        insert(:celo_election_reward,
          epoch_number: epoch3.number,
          type: :delegated_payment,
          amount: 400,
          account_address_hash: account.hash,
          associated_account_address_hash: associated.hash
        )

        insert(:celo_election_reward,
          epoch_number: epoch3.number,
          type: :delegated_payment,
          amount: 500,
          account_address_hash: account2.hash,
          associated_account_address_hash: associated.hash
        )

        # Run migration
        {:ok, _} = CeloAggregatedElectionRewards.start_link([])
        Process.sleep(1000)

        # Verify all epochs were processed
        aggregated_rewards = Repo.all(AggregatedElectionReward)

        # Each epoch has different reward types with data:
        # epoch1: voter, validator (2 types)
        # epoch2: group (1 type)
        # epoch3: delegated_payment (1 type)
        # Total: 4 aggregated records (only non-zero values)
        assert length(aggregated_rewards) == 4

        epoch_numbers = Enum.map(aggregated_rewards, & &1.epoch_number) |> Enum.uniq() |> Enum.sort()
        assert epoch_numbers == [10, 11, 12]

        # Verify epoch 1
        epoch1_rewards =
          Enum.filter(aggregated_rewards, &(&1.epoch_number == epoch1.number))
          |> Enum.sort_by(& &1.type)

        voter1 = Enum.find(epoch1_rewards, &(&1.type == :voter))
        assert voter1.count == 1
        assert Decimal.to_integer(voter1.sum.value) == 100

        validator1 = Enum.find(epoch1_rewards, &(&1.type == :validator))
        assert validator1.count == 1
        assert Decimal.to_integer(validator1.sum.value) == 200

        # Verify epoch 3
        epoch3_rewards = Enum.filter(aggregated_rewards, &(&1.epoch_number == epoch3.number))
        delegated3 = Enum.find(epoch3_rewards, &(&1.type == :delegated_payment))
        assert delegated3.count == 2
        assert Decimal.to_integer(delegated3.sum.value) == 900

        # Confirm migration status is completed
        assert MigrationStatus.get_status("celo_aggregated_election_rewards") == "completed"
      end

      test "is idempotent - does not duplicate data when run multiple times" do
        epoch = insert(:celo_epoch, number: 99, end_processing_block_hash: insert(:block).hash)

        account = insert(:address)
        associated = insert(:address)

        insert(:celo_election_reward,
          epoch_number: epoch.number,
          type: :voter,
          amount: 7777,
          account_address_hash: account.hash,
          associated_account_address_hash: associated.hash
        )

        # Run migration first time
        {:ok, _pid} = CeloAggregatedElectionRewards.start_link([])
        Process.sleep(500)

        # Verify data was created (only 1 type has data, so only 1 aggregate)
        assert Repo.aggregate(AggregatedElectionReward, :count) == 1

        initial_rewards =
          from(aer in AggregatedElectionReward, order_by: [asc: aer.type])
          |> Repo.all()

        # Reset migration status to simulate running again
        MigrationStatus.set_status("celo_aggregated_election_rewards", nil)

        # Run migration second time
        {:ok, _pid} = CeloAggregatedElectionRewards.start_link([])
        Process.sleep(500)

        # Verify data was not duplicated
        assert Repo.aggregate(AggregatedElectionReward, :count) == 1

        final_rewards =
          from(aer in AggregatedElectionReward, order_by: [asc: aer.type])
          |> Repo.all()

        # Data should be identical
        Enum.zip(initial_rewards, final_rewards)
        |> Enum.each(fn {initial, final} ->
          assert initial.epoch_number == final.epoch_number
          assert initial.type == final.type
          assert initial.count == final.count
          assert Decimal.equal?(initial.sum.value, final.sum.value)
        end)
      end

      test "processes epochs in ascending order" do
        # Create epochs out of order
        epoch3 = insert(:celo_epoch, number: 33, end_processing_block_hash: insert(:block).hash)
        epoch1 = insert(:celo_epoch, number: 31, end_processing_block_hash: insert(:block).hash)
        epoch2 = insert(:celo_epoch, number: 32, end_processing_block_hash: insert(:block).hash)

        # Create addresses
        account = insert(:address)
        associated = insert(:address)

        # Add minimal rewards
        for epoch <- [epoch1, epoch2, epoch3] do
          insert(:celo_election_reward,
            epoch_number: epoch.number,
            type: :voter,
            amount: 100 * epoch.number,
            account_address_hash: account.hash,
            associated_account_address_hash: associated.hash
          )
        end

        # Run migration
        {:ok, _} = CeloAggregatedElectionRewards.start_link([])
        Process.sleep(1000)

        # Verify all epochs were processed
        aggregated_rewards =
          from(aer in AggregatedElectionReward,
            where: aer.type == :voter,
            order_by: [asc: aer.epoch_number]
          )
          |> Repo.all()

        assert length(aggregated_rewards) == 3
        assert Enum.at(aggregated_rewards, 0).epoch_number == 31
        assert Enum.at(aggregated_rewards, 1).epoch_number == 32
        assert Enum.at(aggregated_rewards, 2).epoch_number == 33
      end

      test "handles epoch with no election rewards" do
        # Create epoch with no rewards
        epoch = insert(:celo_epoch, number: 999, end_processing_block_hash: insert(:block).hash)

        # Run migration
        {:ok, _} = CeloAggregatedElectionRewards.start_link([])
        Process.sleep(500)

        # Verify no aggregates were created (no zero-value entries)
        aggregated_rewards =
          from(aer in AggregatedElectionReward,
            where: aer.epoch_number == ^epoch.number,
            order_by: [asc: aer.type]
          )
          |> Repo.all()

        # No rewards means no aggregated entries
        assert length(aggregated_rewards) == 0
      end
    end
  end
end
