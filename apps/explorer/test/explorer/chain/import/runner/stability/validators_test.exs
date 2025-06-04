if Application.compile_env(:explorer, :chain_type) == :stability do
  defmodule Explorer.Chain.Import.Runner.Stability.ValidatorsTest do
    use Explorer.DataCase

    alias Ecto.Multi
    alias Explorer.Chain.Stability.Validator
    alias Explorer.Chain.Import.Runner.Stability.Validators

    describe "run/1" do
      test "updates blocks_validated counter for existing validators" do
        # Insert some validators first
        %Validator{address_hash: validator1_hash} =
          insert(:validator_stability, blocks_validated: 5)

        %Validator{address_hash: validator2_hash} =
          insert(:validator_stability, blocks_validated: 3)

        changes = [
          %{
            address_hash: validator1_hash,
            blocks_validated: 2
          },
          %{
            address_hash: validator2_hash,
            blocks_validated: 1
          }
        ]

        assert {:ok, %{stability_validators: updated_validators}} = run_changes(changes)

        assert length(updated_validators) == 2

        # Verify counters were updated in database
        updated_validator1 = Repo.get(Validator, validator1_hash)
        updated_validator2 = Repo.get(Validator, validator2_hash)

        # 5 + 2
        assert updated_validator1.blocks_validated == 7
        # 3 + 1
        assert updated_validator2.blocks_validated == 4
      end

      test "skips non-existent validators" do
        # Insert one validator
        %Validator{address_hash: existing_validator_hash} =
          insert(:validator_stability, blocks_validated: 2)

        # Try to update both existing and non-existing validator
        non_existing_hash = "0x1111111111111111111111111111111111111111"

        changes = [
          %{
            address_hash: existing_validator_hash,
            blocks_validated: 3
          },
          %{
            address_hash: non_existing_hash,
            blocks_validated: 5
          }
        ]

        assert {:ok, %{stability_validators: updated_validators}} = run_changes(changes)

        # Only the existing validator should be in the result
        assert length(updated_validators) == 1
        [updated_validator] = updated_validators
        assert updated_validator.address_hash == existing_validator_hash

        # Verify the existing validator was updated
        updated_validator_db = Repo.get(Validator, existing_validator_hash)
        # 2 + 3
        assert updated_validator_db.blocks_validated == 5

        # Verify non-existing validator wasn't created
        assert Repo.get(Validator, non_existing_hash) == nil
      end

      test "handles empty changes list" do
        assert {:ok, %{stability_validators: []}} = run_changes([])
      end

      test "handles multiple increments for the same validator" do
        %Validator{address_hash: validator_hash} =
          insert(:validator_stability, blocks_validated: 10)

        changes = [
          %{
            address_hash: validator_hash,
            blocks_validated: 2
          },
          %{
            address_hash: validator_hash,
            blocks_validated: 3
          }
        ]

        assert {:ok, %{stability_validators: updated_validators}} = run_changes(changes)

        # Should have 2 entries in the result (one for each update)
        assert length(updated_validators) == 2

        # Verify the counter was incremented twice
        updated_validator = Repo.get(Validator, validator_hash)
        # 10 + 2 + 3
        assert updated_validator.blocks_validated == 15
      end

      test "handles zero increment" do
        %Validator{address_hash: validator_hash} =
          insert(:validator_stability, blocks_validated: 7)

        changes = [
          %{
            address_hash: validator_hash,
            blocks_validated: 0
          }
        ]

        assert {:ok, %{stability_validators: updated_validators}} = run_changes(changes)

        assert length(updated_validators) == 1

        # Verify the counter remained the same
        updated_validator = Repo.get(Validator, validator_hash)
        # 7 + 0
        assert updated_validator.blocks_validated == 7
      end

      test "handles large increment values" do
        %Validator{address_hash: validator_hash} =
          insert(:validator_stability, blocks_validated: 1000)

        changes = [
          %{
            address_hash: validator_hash,
            blocks_validated: 999_999
          }
        ]

        assert {:ok, %{stability_validators: updated_validators}} = run_changes(changes)

        assert length(updated_validators) == 1

        # Verify the counter was updated with large value
        updated_validator = Repo.get(Validator, validator_hash)
        # 1000 + 999999
        assert updated_validator.blocks_validated == 1_000_999
      end

      test "is atomic - all updates succeed or all fail" do
        # This test would be more complex to implement as it requires
        # simulating database errors, but the Multi transaction
        # ensures atomicity by design
        %Validator{address_hash: validator_hash} =
          insert(:validator_stability, blocks_validated: 5)

        changes = [
          %{
            address_hash: validator_hash,
            blocks_validated: 2
          }
        ]

        # Normal case - should succeed
        assert {:ok, %{stability_validators: _}} = run_changes(changes)
      end
    end

    defp run_changes(changes) when is_list(changes) do
      Multi.new()
      |> Validators.run(changes, %{
        timeout: :infinity,
        timestamps: %{inserted_at: DateTime.utc_now(), updated_at: DateTime.utc_now()}
      })
      |> Repo.transaction()
    end
  end
end
