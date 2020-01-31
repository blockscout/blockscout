defmodule Explorer.ChainSpec.Parity.ImporterTest do
  use Explorer.DataCase

  alias Explorer.Chain.Address.CoinBalance
  alias Explorer.Chain.Block.{EmissionReward, Range}
  alias Explorer.Chain.{Address, Hash, Wei}
  alias Explorer.ChainSpec.Parity.Importer
  alias Explorer.Repo

  @chain_spec "#{File.cwd!()}/test/support/fixture/chain_spec/foundation.json"
              |> File.read!()
              |> Jason.decode!()

  @chain_classic_spec "#{File.cwd!()}/test/support/fixture/chain_spec/classic.json"
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

    test "fetches and formats a single reward" do
      assert Importer.emission_rewards(@chain_classic_spec) == [
               %{
                 block_range: %Range{from: 1, to: :infinity},
                 reward: %Wei{value: Decimal.new(5_000_000_000_000_000_000)}
               }
             ]
    end
  end

  describe "import_emission_rewards/1" do
    test "inserts emission rewards from chain spec" do
      assert {3, nil} = Importer.import_emission_rewards(@chain_spec)
    end

    test "rewrites all recored" do
      old_block_rewards = %{
        "0x0" => "0x1bc16d674ec80000",
        "0x42ae50" => "0x29a2241af62c0000",
        "0x6f1580" => "0x4563918244f40000"
      }

      chain_spec = %{
        @chain_spec
        | "engine" => %{
            @chain_spec["engine"]
            | "Ethash" => %{
                @chain_spec["engine"]["Ethash"]
                | "params" => %{@chain_spec["engine"]["Ethash"]["params"] | "blockReward" => old_block_rewards}
              }
          }
      }

      assert {3, nil} = Importer.import_emission_rewards(chain_spec)
      [first, second, third] = Repo.all(EmissionReward)

      assert first.reward == %Wei{value: Decimal.new(2_000_000_000_000_000_000)}
      assert first.block_range == %Range{from: 0, to: 4_370_000}

      assert second.reward == %Wei{value: Decimal.new(3_000_000_000_000_000_000)}
      assert second.block_range == %Range{from: 4_370_001, to: 7_280_000}

      assert third.reward == %Wei{value: Decimal.new(5_000_000_000_000_000_000)}
      assert third.block_range == %Range{from: 7_280_001, to: :infinity}

      assert {3, nil} = Importer.import_emission_rewards(@chain_spec)
      [new_first, new_second, new_third] = Repo.all(EmissionReward)

      assert new_first.reward == %Wei{value: Decimal.new(5_000_000_000_000_000_000)}
      assert new_first.block_range == %Range{from: 0, to: 4_370_000}

      assert new_second.reward == %Wei{value: Decimal.new(3_000_000_000_000_000_000)}
      assert new_second.block_range == %Range{from: 4_370_001, to: 7_280_000}

      assert new_third.reward == %Wei{value: Decimal.new(2_000_000_000_000_000_000)}
      assert new_third.block_range == %Range{from: 7_280_001, to: :infinity}
    end
  end

  describe "genesis_coin_balances/1" do
    test "parses coin balance" do
      coin_balances = Importer.genesis_coin_balances(@chain_spec)

      assert Enum.count(coin_balances) == 403

      assert %{
               address_hash: %Hash{
                 byte_count: 20,
                 bytes: <<121, 174, 179, 69, 102, 185, 116, 195, 90, 88, 129, 222, 192, 32, 146, 125, 167, 223, 93, 37>>
               },
               value: 2_000_000_000_000_000_000_000
             } ==
               List.first(coin_balances)
    end
  end

  describe "import_genesis_coin_balances/1" do
    test "imports coin balances" do
      {:ok, %{address_coin_balances: address_coin_balances}} = Importer.import_genesis_coin_balances(@chain_spec)

      assert Enum.count(address_coin_balances) == 403
      assert CoinBalance |> Repo.all() |> Enum.count() == 403
      assert Address |> Repo.all() |> Enum.count() == 403
    end

    test "imports coin balances without 0x" do
      {:ok, %{address_coin_balances: address_coin_balances}} =
        Importer.import_genesis_coin_balances(@chain_classic_spec)

      assert Enum.count(address_coin_balances) == 8894
      assert CoinBalance |> Repo.all() |> Enum.count() == 8894
      assert Address |> Repo.all() |> Enum.count() == 8894
    end
  end
end
