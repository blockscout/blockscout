# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Chain.BlockNumberHelperTest do
  use Explorer.DataCase

  import Explorer.QuerySources, only: [with_query_sources: 1]

  alias Explorer.Chain.BlockNumberHelper

  describe "previous_block_numbers/1" do
    test "matches previous_block_number/1 for every block" do
      numbers = [0, 1, 5, 100]

      assert BlockNumberHelper.previous_block_numbers(numbers) ==
               Map.new(numbers, &{&1, BlockNumberHelper.previous_block_number(&1)})
    end

    if Application.compile_env(:explorer, :chain_type) == :filecoin do
      test "looks the null rounds up for the whole batch with a single query" do
        Explorer.Chain.NullRoundHeight.insert_heights([99, 102])

        assert with_query_sources(fn -> BlockNumberHelper.previous_block_numbers([100, 101, 103]) end) ==
                 {%{100 => 98, 101 => 100, 103 => 101}, ["null_round_heights"]}
      end
    else
      test "makes no queries" do
        assert with_query_sources(fn -> BlockNumberHelper.previous_block_numbers([100, 101, 103]) end) ==
                 {%{100 => 99, 101 => 100, 103 => 102}, []}
      end
    end
  end
end
