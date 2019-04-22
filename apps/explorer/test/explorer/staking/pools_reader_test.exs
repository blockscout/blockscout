defmodule Explorer.Token.PoolsReaderTest do
  use EthereumJSONRPC.Case
  use Explorer.DataCase

  alias Explorer.Staking.PoolsReader

  import Mox

  setup :verify_on_exit!
  setup :set_mox_global

  describe "get_pools_list" do
    test "get_active_pools success" do
      get_pools_from_blockchain()

      result = PoolsReader.get_active_pools()

      assert Enum.count(result) == 3
    end

    test "get_active_pools error" do
      fetch_from_blockchain_with_error()

      assert_raise MatchError, fn ->
        PoolsReader.get_active_pools()
      end
    end
  end

  describe "get_pools_data" do
    test "get_pool_data success" do
      get_pool_data_from_blockchain()

      address = <<11, 47, 94, 47, 60, 189, 134, 78, 170, 44, 100, 46, 55, 105, 193, 88, 35, 97, 202, 246>>

      response = {
        :ok,
        %{
          banned_unitil: 0,
          delegators_count: 0,
          is_active: true,
          is_banned: false,
          is_validator: true,
          mining_address:
            <<187, 202, 168, 212, 130, 137, 187, 31, 252, 249, 128, 141, 154, 164, 177, 210, 21, 5, 76, 120>>,
          staked_amount: 0,
          staking_address: <<11, 47, 94, 47, 60, 189, 134, 78, 170, 44, 100, 46, 55, 105, 193, 88, 35, 97, 202, 246>>,
          was_banned_count: 0,
          was_validator_count: 2
        }
      }

      assert PoolsReader.pool_data(address) == response
    end

    test "get_pool_data error" do
      fetch_from_blockchain_with_error()

      address = <<11, 47, 94, 47, 60, 189, 134, 78, 170, 44, 100, 46, 55, 105, 193, 88, 35, 97, 202, 246>>

      assert :error = PoolsReader.pool_data(address)
    end
  end

  defp get_pools_from_blockchain() do
    expect(
      EthereumJSONRPC.Mox,
      :json_rpc,
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

  defp fetch_from_blockchain_with_error() do
    expect(
      EthereumJSONRPC.Mox,
      :json_rpc,
      fn [%{id: id, method: "eth_call", params: _}], _options ->
        {:ok,
         [
           %{
             error: %{code: -32015, data: "Reverted 0x", message: "VM execution error."},
             id: id,
             jsonrpc: "2.0"
           }
         ]}
      end
    )
  end

  defp get_pool_data_from_blockchain() do
    expect(
      EthereumJSONRPC.Mox,
      :json_rpc,
      9,
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
