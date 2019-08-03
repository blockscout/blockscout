defmodule Explorer.ChainSpec.Parity.ImporterTest do
  use Explorer.DataCase

  alias Explorer.Chain.Block.Range
  alias Explorer.Chain.Wei
  alias Explorer.ChainSpec.Parity.Importer

  @chain_spec "#{File.cwd!()}/test/support/fixture/chain_spec/foundation.json"
              |> File.read!()
              |> Jason.decode!()

  describe "emission_rewards/1" do
    test "fetches and formats reward ranges" do
      assert Importer.emission_rewards(@chain_spec) == [
               %{
                 block_range: %Range{from: 0, to: 4_370_000},
                 reward: %Wei{value: Decimal.new(5_000_000_000_000_000_000)}
               },
               %{
                 block_range: %Range{from: 4_370_001, to: 7_280_000},
                 reward: %Wei{value: Decimal.new(3_000_000_000_000_000_000)}
               },
               %{
                 block_range: %Range{from: 7_280_001, to: :infinity},
                 reward: %Wei{value: Decimal.new(2_000_000_000_000_000_000)}
               }
             ]
    end
  end

  describe "import_emission_rewards/1" do
    test "inserts emission rewards from chain spec" do
      assert {3, nil} = Importer.import_emission_rewards(@chain_spec)
    end
  end
end
