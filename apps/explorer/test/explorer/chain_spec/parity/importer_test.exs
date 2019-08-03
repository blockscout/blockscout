defmodule Explorer.ChainSpec.Parity.ImporterTest do
  use ExUnit.Case

  alias Explorer.ChainSpec.Parity.Importer

  @chain_spec "#{File.cwd!()}/test/support/fixture/chain_spec/foundation.json"
              |> File.read!()
              |> Jason.decode!()

  describe "emission_rewards/1" do
    test "fetches and formats reward ranges" do
      assert Importer.emission_rewards(@chain_spec) == [
               %{block_range: 0..4_370_000, reward: 5_000_000_000_000_000_000},
               %{block_range: 4_370_000..7_280_000, reward: 3_000_000_000_000_000_000},
               %{block_range: 7_280_000..9_999_999_999_999_999_999, reward: 2_000_000_000_000_000_000}
             ]
    end
  end
end
