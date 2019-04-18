defmodule Explorer.Chain.Import.Runner.ValidatorsTest do
  use Explorer.DataCase

  alias Ecto.Multi
  alias Explorer.Chain.Import.Runner.Validators

  describe "run/1" do
    test "insert new validators list" do
      validators = [
        %{
          address_hash: %Explorer.Chain.Hash{
            byte_count: 20,
            bytes: <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1>>
          },
          metadata: %{active: true, type: "validator"},
          name: "anonymous",
          primary: true
        },
        %{
          address_hash: %Explorer.Chain.Hash{
            byte_count: 20,
            bytes: <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2>>
          },
          metadata: %{active: true, type: "validator"},
          name: "anonymous",
          primary: true
        },
        %{
          address_hash: %Explorer.Chain.Hash{
            byte_count: 20,
            bytes: <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3>>
          },
          metadata: %{active: true, type: "validator"},
          name: "anonymous",
          primary: true
        }
      ]

      assert {:ok, %{deactivate_old_validators: 0, validators: list}} = run_changes(validators)
      assert Enum.count(list) == Enum.count(validators)
    end

    test "deactivate old validators and set new" do
      old_list = [
        insert(:address_name, primary: true, metadata: %{active: true, type: "validator"}),
        insert(:address_name, primary: true, metadata: %{active: true, type: "validator"})
      ]

      new_list = [
        %{
          address_hash: %Explorer.Chain.Hash{
            byte_count: 20,
            bytes: <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1>>
          },
          metadata: %{active: true, type: "validator"},
          name: "anonymous",
          primary: true
        },
        %{
          address_hash: %Explorer.Chain.Hash{
            byte_count: 20,
            bytes: <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2>>
          },
          metadata: %{active: true, type: "validator"},
          name: "anonymous",
          primary: true
        }
      ]

      assert {:ok, %{deactivate_old_validators: deactivate_count, validators: list}} = run_changes(new_list)
      assert Enum.count(list) == Enum.count(new_list)
      assert deactivate_count == Enum.count(old_list)
    end
  end

  defp run_changes(changes) do
    Multi.new()
    |> Validators.run(changes, %{
      timeout: :infinity,
      timestamps: %{inserted_at: DateTime.utc_now(), updated_at: DateTime.utc_now()}
    })
    |> Repo.transaction()
  end
end
