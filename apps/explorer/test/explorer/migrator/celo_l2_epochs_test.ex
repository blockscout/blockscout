defmodule Explorer.Migrator.CeloL2EpochsTest do
  use Explorer.DataCase, async: false

  use Utils.CompileTimeEnvHelper,
    chain_type: [:explorer, :chain_type]

  if @chain_type == :celo do
    alias Explorer.Migrator.{CeloL2Epochs, MigrationStatus}
    alias Explorer.Chain.Celo.Epoch
    alias Explorer.Repo

    import Ecto.Query

    describe "celo_l2_epochs migration" do
      test "backfills epochs from logs" do
        epoch_manager_address = insert(:address, hash: "0x8d3436d48e1e3d915a0a6948049b0f58a79c9bbb")

        old_env = Application.get_env(:explorer, :celo)

        Application.put_env(
          :explorer,
          :celo,
          Keyword.put(
            old_env,
            :epoch_manager_contract_address,
            to_string(epoch_manager_address.hash)
          )
        )

        on_exit(fn ->
          Application.put_env(:explorer, :celo, old_env)
        end)

        # Create test logs for epoch processing events
        epoch_number = 42
        epoch_number_hex = "0x000000000000000000000000000000000000000000000000000000000000002a"

        # Add epoch_processing_started event log
        start_log =
          insert(:log,
            address: epoch_manager_address,
            # epoch_processing_started
            first_topic: "0xae58a33f8b8d696bcbaca9fa29d9fdc336c140e982196c2580db3d46f3e6d4b6",
            second_topic: epoch_number_hex
          )

        # Add epoch_processing_ended event log
        end_log =
          insert(:log,
            address: epoch_manager_address,
            # epoch_processing_ended
            first_topic: "0xc8e58d8e6979dd5e68bad79d4a4368a1091f6feb2323e612539b1b84e0663a8f",
            second_topic: epoch_number_hex
          )

        # Ensure migration has not run yet
        assert MigrationStatus.get_status("celo_l2_epochs") == nil

        # Run migration process
        {:ok, _} = CeloL2Epochs.start_link([])

        # Wait for migration to complete
        Process.sleep(500)

        # Verify epoch was properly created
        epochs = Repo.all(from(e in Epoch, where: e.number == ^epoch_number))

        assert length(epochs) == 1
        epoch = List.first(epochs)

        # Check epoch data matches our logs
        assert epoch.number == epoch_number
        assert epoch.start_processing_block_hash == start_log.block_hash
        assert epoch.end_processing_block_hash == end_log.block_hash
        assert epoch.fetched? == false

        # Confirm migration status is completed
        assert MigrationStatus.get_status("celo_l2_epochs") == "completed"
      end

      test "backfills multiple epochs from logs" do
        epoch_manager_address = insert(:address, hash: "0x8d3436d48e1e3d915a0a6948049b0f58a79c9bbb")

        old_env = Application.get_env(:explorer, :celo)

        Application.put_env(:explorer, :celo, [
          {
            :epoch_manager_contract_address,
            to_string(epoch_manager_address.hash)
          }
          | old_env
        ])

        on_exit(fn ->
          Application.put_env(:explorer, :celo, old_env)
        end)

        # Create data for 3 epochs with different patterns
        epoch_data = [
          # Standard epoch with start and end events
          %{
            number: 42,
            number_hex: "0x000000000000000000000000000000000000000000000000000000000000002a"
          },
          # Another complete epoch
          %{
            number: 43,
            number_hex: "0x000000000000000000000000000000000000000000000000000000000000002b"
          },
          # Epoch with only a start event (incomplete)
          %{
            number: 44,
            number_hex: "0x000000000000000000000000000000000000000000000000000000000000002c"
          }
        ]

        # Insert logs for each epoch
        start_logs =
          Enum.map(epoch_data, fn epoch ->
            insert(:log,
              address: epoch_manager_address,
              first_topic: "0xae58a33f8b8d696bcbaca9fa29d9fdc336c140e982196c2580db3d46f3e6d4b6",
              second_topic: epoch.number_hex
            )
          end)

        # Insert end logs for all except the last epoch
        end_logs =
          Enum.slice(epoch_data, 0..1)
          |> Enum.map(fn epoch ->
            insert(:log,
              address: epoch_manager_address,
              first_topic: "0xc8e58d8e6979dd5e68bad79d4a4368a1091f6feb2323e612539b1b84e0663a8f",
              second_topic: epoch.number_hex
            )
          end)

        # Ensure migration has not run yet
        assert MigrationStatus.get_status("celo_l2_epochs") == nil

        # Run migration process
        {:ok, _} = CeloL2Epochs.start_link([])

        # Wait for migration to complete
        Process.sleep(1000)

        # Verify all epochs were properly created
        created_epochs = Repo.all(from(e in Epoch, order_by: [asc: e.number]))

        # Should have created all three epochs
        assert length(created_epochs) == 3

        # Check first epoch (complete)
        first_epoch = Enum.at(created_epochs, 0)
        assert first_epoch.number == 42
        assert first_epoch.start_processing_block_hash == Enum.at(start_logs, 0).block_hash
        assert first_epoch.end_processing_block_hash == Enum.at(end_logs, 0).block_hash
        assert first_epoch.fetched? == false

        # Check second epoch (complete)
        second_epoch = Enum.at(created_epochs, 1)
        assert second_epoch.number == 43
        assert second_epoch.start_processing_block_hash == Enum.at(start_logs, 1).block_hash
        assert second_epoch.end_processing_block_hash == Enum.at(end_logs, 1).block_hash
        assert second_epoch.fetched? == false

        # Check third epoch (incomplete - only has start)
        third_epoch = Enum.at(created_epochs, 2)
        assert third_epoch.number == 44
        assert third_epoch.start_processing_block_hash == Enum.at(start_logs, 2).block_hash
        assert third_epoch.end_processing_block_hash == nil
        assert third_epoch.fetched? == false

        # Confirm migration status is completed
        assert MigrationStatus.get_status("celo_l2_epochs") == "completed"
      end
    end
  end
end
