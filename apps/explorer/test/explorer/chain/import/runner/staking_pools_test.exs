defmodule Explorer.Chain.Import.Runner.StakingPoolsTest do
  use Explorer.DataCase

  alias Ecto.Multi
  alias Explorer.Chain.Import.Runner.StakingPools

  describe "run/1" do
    test "insert new pools list" do
      pools = [
        %{
          address_hash: %Explorer.Chain.Hash{
            byte_count: 20,
            bytes: <<11, 47, 94, 47, 60, 189, 134, 78, 170, 44, 100, 46, 55, 105, 193, 88, 35, 97, 202, 246>>
          },
          metadata: %{
            banned_unitil: 0,
            delegators_count: 0,
            is_active: true,
            is_banned: false,
            is_validator: true,
            mining_address: %Explorer.Chain.Hash{
              byte_count: 20,
              bytes: <<187, 202, 168, 212, 130, 137, 187, 31, 252, 249, 128, 141, 154, 164, 177, 210, 21, 5, 76, 120>>
            },
            retries_count: 1,
            staked_amount: 0,
            was_banned_count: 0,
            was_validator_count: 1
          },
          name: "anonymous",
          primary: true
        },
        %{
          address_hash: %Explorer.Chain.Hash{
            byte_count: 20,
            bytes: <<170, 148, 182, 135, 211, 249, 85, 42, 69, 59, 129, 178, 131, 76, 165, 55, 120, 152, 13, 192>>
          },
          metadata: %{
            banned_unitil: 0,
            delegators_count: 0,
            is_active: true,
            is_banned: false,
            is_validator: true,
            mining_address: %Explorer.Chain.Hash{
              byte_count: 20,
              bytes: <<117, 223, 66, 56, 58, 254, 107, 245, 25, 74, 168, 250, 14, 155, 61, 95, 158, 134, 148, 65>>
            },
            retries_count: 1,
            staked_amount: 0,
            was_banned_count: 0,
            was_validator_count: 1
          },
          name: "anonymous",
          primary: true
        },
        %{
          address_hash: %Explorer.Chain.Hash{
            byte_count: 20,
            bytes: <<49, 44, 35, 14, 125, 109, 176, 82, 36, 246, 2, 8, 166, 86, 227, 84, 28, 92, 66, 186>>
          },
          metadata: %{
            banned_unitil: 0,
            delegators_count: 0,
            is_active: true,
            is_banned: false,
            is_validator: true,
            mining_address: %Explorer.Chain.Hash{
              byte_count: 20,
              bytes: <<82, 45, 243, 150, 174, 112, 160, 88, 189, 105, 119, 132, 8, 99, 15, 219, 2, 51, 137, 178>>
            },
            retries_count: 1,
            staked_amount: 0,
            was_banned_count: 0,
            was_validator_count: 1
          },
          name: "anonymous",
          primary: true
        }
      ]

      assert {:ok, %{insert_staking_pools: list}} = run_changes(pools)
      assert Enum.count(list) == Enum.count(pools)
    end
  end

  defp run_changes(changes) do
    Multi.new()
    |> StakingPools.run(changes, %{
      timeout: :infinity,
      timestamps: %{inserted_at: DateTime.utc_now(), updated_at: DateTime.utc_now()}
    })
    |> Repo.transaction()
  end
end
