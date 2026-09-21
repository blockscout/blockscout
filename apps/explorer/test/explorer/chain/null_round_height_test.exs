# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Chain.NullRoundHeightTest do
  use Explorer.DataCase

  import Explorer.QuerySources, only: [with_query_sources: 1]

  alias Explorer.Chain.NullRoundHeight

  if Application.compile_env(:explorer, :chain_type) == :filecoin do
    describe "neighbor_block_numbers/2" do
      test "skips the null rounds of the batch with a single query" do
        NullRoundHeight.insert_heights([99, 102, 103, 106])

        {previous, query_sources} =
          with_query_sources(fn -> NullRoundHeight.neighbor_block_numbers([100, 101, 104, 105, 107], :previous) end)

        assert previous == %{100 => 98, 101 => 100, 104 => 101, 105 => 104, 107 => 105}
        assert query_sources == ["null_round_heights"]

        {next, query_sources} =
          with_query_sources(fn -> NullRoundHeight.neighbor_block_numbers([98, 100, 101, 104, 105], :next) end)

        assert next == %{98 => 100, 100 => 101, 101 => 104, 104 => 105, 105 => 107}
        assert query_sources == ["null_round_heights"]
      end

      test "matches neighbor_block_number/2 for every block" do
        NullRoundHeight.insert_heights([99, 102, 103, 106])
        numbers = [90, 100, 101, 104, 105, 107, 120]

        for direction <- [:previous, :next] do
          neighbors = NullRoundHeight.neighbor_block_numbers(numbers, direction)

          for number <- numbers do
            assert neighbors[number] == NullRoundHeight.neighbor_block_number(number, direction)
          end
        end
      end

      test "looks further when a run of null rounds beyond the farthest block exceeds the fetched batch" do
        NullRoundHeight.insert_heights(Enum.to_list(80..99))

        {previous, query_sources} =
          with_query_sources(fn -> NullRoundHeight.neighbor_block_numbers([100, 101], :previous) end)

        assert previous == %{100 => 79, 101 => 100}
        assert length(query_sources) > 1

        assert NullRoundHeight.neighbor_block_numbers([78, 79], :next) == %{78 => 79, 79 => 100}
      end

      test "skips a run of null rounds as long as the fetched batch with a single query" do
        # A batch of 5 null rounds is fetched for a single block
        NullRoundHeight.insert_heights(Enum.to_list(95..99))

        assert with_query_sources(fn -> NullRoundHeight.neighbor_block_numbers([100], :previous) end) ==
                 {%{100 => 94}, ["null_round_heights"]}

        assert with_query_sources(fn -> NullRoundHeight.neighbor_block_numbers([94], :next) end) ==
                 {%{94 => 100}, ["null_round_heights"]}
      end

      test "looks the neighbors of sparse blocks up separately rather than fetching their whole span" do
        NullRoundHeight.insert_heights(Enum.to_list(1_000..1_100))

        {previous, query_sources} =
          with_query_sources(fn -> NullRoundHeight.neighbor_block_numbers([999, 5_000], :previous) end)

        # The batch fetched below the farthest block doesn't reach the lower one, which is looked up separately
        assert previous == %{999 => 998, 5_000 => 4_999}
        assert length(query_sources) == 2
      end

      test "returns an empty map for no blocks" do
        assert with_query_sources(fn -> NullRoundHeight.neighbor_block_numbers([], :previous) end) == {%{}, []}
      end
    end
  end
end
