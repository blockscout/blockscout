# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Chain.Optimism.EIP1559ConfigUpdateTest do
  use Explorer.DataCase

  import Explorer.QuerySources, only: [with_query_sources: 1]

  alias Explorer.Chain.Optimism.EIP1559ConfigUpdate

  if Application.compile_env(:explorer, :chain_type) == :optimism do
    describe "actual_configs_for_blocks/1" do
      test "returns the config actual before each block with a single query" do
        insert_update(10, 50, 6)
        insert_update(20, 100, 8)
        insert_update(30, 150, 10)

        {configs, query_sources} =
          with_query_sources(fn -> EIP1559ConfigUpdate.actual_configs_for_blocks([5, 10, 11, 25, 30, 31]) end)

        assert configs == %{
                 5 => nil,
                 10 => nil,
                 11 => {50, 6, nil},
                 25 => {100, 8, nil},
                 30 => {100, 8, nil},
                 31 => {150, 10, nil}
               }

        assert query_sources == ["op_eip1559_config_updates"]
      end

      test "matches actual_config_for_block/1 for every block" do
        insert_update(10, 50, 6)
        insert_update(20, 100, 8)

        block_numbers = [1, 10, 11, 20, 21, 100]
        configs = EIP1559ConfigUpdate.actual_configs_for_blocks(block_numbers)

        for block_number <- block_numbers do
          assert configs[block_number] == EIP1559ConfigUpdate.actual_config_for_block(block_number)
        end
      end

      test "finds the update registered long before the batch" do
        insert_update(10, 50, 6)
        insert_update(200, 100, 8)

        assert EIP1559ConfigUpdate.actual_configs_for_blocks([100, 101]) == %{100 => {50, 6, nil}, 101 => {50, 6, nil}}
      end

      test "returns an empty map for no blocks" do
        assert EIP1559ConfigUpdate.actual_configs_for_blocks([]) == %{}
      end
    end

    defp insert_update(l2_block_number, denominator, multiplier) do
      %EIP1559ConfigUpdate{}
      |> EIP1559ConfigUpdate.changeset(%{
        l2_block_number: l2_block_number,
        l2_block_hash: block_hash(),
        base_fee_max_change_denominator: denominator,
        elasticity_multiplier: multiplier
      })
      |> Repo.insert!()
    end
  end
end
