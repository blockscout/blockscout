defmodule Indexer.Fetcher.StakingPoolsTest do
  use EthereumJSONRPC.Case
  use Explorer.DataCase

  import Mox

  alias Indexer.Fetcher.StakingPools
  alias Explorer.Staking.PoolsReader
  alias Explorer.Chain.Address

  @moduletag :capture_log

  setup :verify_on_exit!

  describe "init/3" do
    test "returns pools addresses" do
      get_pools_from_blockchain(2)

      list = StakingPools.init([], &[&1 | &2], [])

      assert Enum.count(list) == 6
    end
  end

  describe "run/3" do
    test "one success import from pools" do
      get_pools_from_blockchain(1)

      list =
        PoolsReader.get_active_pools()
        |> Enum.map(&StakingPools.entry/1)

      success_address =
        list
        |> List.first()
        |> Map.get(:staking_address)

      get_pool_data_from_blockchain()

      assert {:retry, retry_list} = StakingPools.run(list, nil)
      assert Enum.count(retry_list) == 2

      pool = Explorer.Repo.get_by(Address.Name, address_hash: success_address)
      assert pool.name == "anonymous"
    end
  end

  defp get_pools_from_blockchain(n) do
    expect(
      EthereumJSONRPC.Mox,
      :json_rpc,
      n,
      fn [%{id: id, method: "eth_call", params: _}], _options ->
        {:ok,
         [
           %{
             id: id,
             jsonrpc: "2.0",
             result:
               "0x000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000030000000000000000000000000b2f5e2f3cbd864eaa2c642e3769c1582361caf6000000000000000000000000aa94b687d3f9552a453b81b2834ca53778980dc0000000000000000000000000312c230e7d6db05224f60208a656e3541c5c42ba"
           }
         ]}
      end
    )
  end

  defp get_pool_data_from_blockchain() do
    expect(
      EthereumJSONRPC.Mox,
      :json_rpc,
      11,
      fn requests, _opts ->
        {:ok,
         Enum.map(requests, fn
           # miningByStakingAddress
           %{
             id: id,
             method: "eth_call",
             params: [
               %{data: "0x005351750000000000000000000000000b2f5e2f3cbd864eaa2c642e3769c1582361caf6", to: _},
               "latest"
             ]
           } ->
             %{
               id: id,
               result: "0x000000000000000000000000bbcaa8d48289bb1ffcf9808d9aa4b1d215054c78"
             }

           # isPoolActive
           %{
             id: id,
             method: "eth_call",
             params: [
               %{data: "0xa711e6a10000000000000000000000000b2f5e2f3cbd864eaa2c642e3769c1582361caf6", to: _},
               "latest"
             ]
           } ->
             %{
               id: id,
               result: "0x0000000000000000000000000000000000000000000000000000000000000001"
             }

           # poolDelegators
           %{
             id: id,
             method: "eth_call",
             params: [
               %{data: "0x9ea8082b0000000000000000000000000b2f5e2f3cbd864eaa2c642e3769c1582361caf6", to: _},
               "latest"
             ]
           } ->
             %{
               id: id,
               result:
                 "0x00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000000"
             }

           # stakeAmountTotalMinusOrderedWithdraw
           %{
             id: id,
             method: "eth_call",
             params: [
               %{data: "0x234fbf2b0000000000000000000000000b2f5e2f3cbd864eaa2c642e3769c1582361caf6", to: _},
               "latest"
             ]
           } ->
             %{
               id: id,
               result: "0x0000000000000000000000000000000000000000000000000000000000000000"
             }

           # isValidator
           %{
             id: id,
             method: "eth_call",
             params: [
               %{data: "0xfacd743b000000000000000000000000bbcaa8d48289bb1ffcf9808d9aa4b1d215054c78", to: _},
               "latest"
             ]
           } ->
             %{
               id: id,
               result: "0x0000000000000000000000000000000000000000000000000000000000000001"
             }

           # validatorCounter
           %{
             id: id,
             method: "eth_call",
             params: [
               %{data: "0xb41832e4000000000000000000000000bbcaa8d48289bb1ffcf9808d9aa4b1d215054c78", to: _},
               "latest"
             ]
           } ->
             %{
               id: id,
               result: "0x0000000000000000000000000000000000000000000000000000000000000002"
             }

           # isValidatorBanned
           %{
             id: id,
             method: "eth_call",
             params: [
               %{data: "0xa92252ae000000000000000000000000bbcaa8d48289bb1ffcf9808d9aa4b1d215054c78", to: _},
               "latest"
             ]
           } ->
             %{
               id: id,
               result: "0x0000000000000000000000000000000000000000000000000000000000000000"
             }

           # bannedUntil
           %{
             id: id,
             method: "eth_call",
             params: [
               %{data: "0x5836d08a000000000000000000000000bbcaa8d48289bb1ffcf9808d9aa4b1d215054c78", to: _},
               "latest"
             ]
           } ->
             %{
               id: id,
               result: "0x0000000000000000000000000000000000000000000000000000000000000000"
             }

           # banCounter
           %{
             id: id,
             method: "eth_call",
             params: [
               %{data: "0x1d0cd4c6000000000000000000000000bbcaa8d48289bb1ffcf9808d9aa4b1d215054c78", to: _},
               "latest"
             ]
           } ->
             %{
               id: id,
               result: "0x0000000000000000000000000000000000000000000000000000000000000000"
             }
         end)}
      end
    )
  end
end
