defmodule Explorer.Chain.Cache.CeloCoreContractsTest do
  use ExUnit.Case, async: true

  alias Explorer.Chain.Cache.CeloCoreContracts

  describe "get_address/2" do
    test "returns address according to block number" do
      first_address = "0xb10ee11244526b94879e1956745ba2e35ae2ba20"

      Application.put_env(:explorer, Explorer.Chain.Cache.CeloCoreContracts,
        contracts: %{
          "addresses" => %{
            "EpochRewards" => [
              %{
                "address" => first_address,
                "updated_at_block_number" => 100
              }
            ]
          }
        }
      )

      on_exit(fn ->
        Application.put_env(:explorer, Explorer.Chain.Cache.CeloCoreContracts, contracts: %{})
      end)

      assert {:error, :address_does_not_exist} = CeloCoreContracts.get_address(:epoch_rewards, 99)
      assert {:ok, ^first_address} = CeloCoreContracts.get_address(:epoch_rewards, 100)
      assert {:ok, ^first_address} = CeloCoreContracts.get_address(:epoch_rewards, 10_000)
    end
  end

  describe "get_event/3" do
    test "returns event according to block number" do
      first_address = "0x0000000000000000000000000000000000000000"
      second_address = "0x22579ca45ee22e2e16ddf72d955d6cf4c767b0ef"

      Application.put_env(:explorer, Explorer.Chain.Cache.CeloCoreContracts,
        contracts: %{
          "addresses" => %{
            "EpochRewards" => [
              %{
                "address" => "0xb10ee11244526b94879e1956745ba2e35ae2ba20",
                "updated_at_block_number" => 100
              }
            ]
          },
          "events" => %{
            "EpochRewards" => %{
              "0xb10ee11244526b94879e1956745ba2e35ae2ba20" => %{
                "CarbonOffsettingFundSet" => [
                  %{
                    "address" => first_address,
                    "updated_at_block_number" => 598
                  },
                  %{
                    "address" => second_address,
                    "updated_at_block_number" => 15_049_265
                  }
                ]
              }
            }
          }
        }
      )

      on_exit(fn ->
        Application.put_env(:explorer, Explorer.Chain.Cache.CeloCoreContracts, contracts: %{})
      end)

      assert {:error, :address_does_not_exist} =
               CeloCoreContracts.get_event(:epoch_rewards, :carbon_offsetting_fund_set, 99)

      assert {:ok, %{"address" => ^first_address, "updated_at_block_number" => 598}} =
               CeloCoreContracts.get_event(:epoch_rewards, :carbon_offsetting_fund_set, 598)

      assert {:ok, %{"address" => ^first_address, "updated_at_block_number" => 598}} =
               CeloCoreContracts.get_event(:epoch_rewards, :carbon_offsetting_fund_set, 599)

      assert {:ok, %{"address" => ^second_address, "updated_at_block_number" => 15_049_265}} =
               CeloCoreContracts.get_event(:epoch_rewards, :carbon_offsetting_fund_set, 16_000_000)
    end
  end
end
