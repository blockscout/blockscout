defmodule Explorer.Token.PoolsReaderTest do
  use EthereumJSONRPC.Case

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

      address = <<219, 156, 178, 71, 141, 145, 119, 25, 197, 56, 98, 0, 134, 114, 22, 104, 8, 37, 133, 119>>

      response =
        {:ok,
         %{
           banned_until: 0,
           is_active: true,
           is_banned: false,
           is_validator: true,
           was_banned_count: 0,
           was_validator_count: 2,
           delegators: [
             %{
               delegator_address_hash:
                 <<243, 231, 124, 74, 245, 235, 47, 51, 175, 255, 118, 25, 216, 209, 231, 81, 215, 24, 164, 145>>,
               max_ordered_withdraw_allowed: 1_000_000_000_000_000_000,
               max_withdraw_allowed: 1_000_000_000_000_000_000,
               ordered_withdraw: 0,
               ordered_withdraw_epoch: 0,
               pool_address_hash:
                 <<219, 156, 178, 71, 141, 145, 119, 25, 197, 56, 98, 0, 134, 114, 22, 104, 8, 37, 133, 119>>,
               stake_amount: 1_000_000_000_000_000_000
             }
           ],
           delegators_count: 1,
           mining_address_hash:
             <<190, 105, 235, 9, 104, 34, 106, 24, 8, 151, 94, 26, 31, 33, 39, 102, 127, 43, 255, 179>>,
           self_staked_amount: 2_000_000_000_000_000_000,
           staked_amount: 3_000_000_000_000_000_000,
           staking_address_hash:
             <<219, 156, 178, 71, 141, 145, 119, 25, 197, 56, 98, 0, 134, 114, 22, 104, 8, 37, 133, 119>>
         }}

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
      3,
      fn requests, _opts ->
        {:ok,
         Enum.map(requests, fn
           # miningByStakingAddress
           %{
             id: id,
             method: "eth_call",
             params: [
               %{data: "0x00535175000000000000000000000000db9cb2478d917719c53862008672166808258577", to: _},
               "latest"
             ]
           } ->
             %{
               id: id,
               result: "0x000000000000000000000000be69eb0968226a1808975e1a1f2127667f2bffb3"
             }

           # isPoolActive
           %{
             id: id,
             method: "eth_call",
             params: [
               %{data: "0xa711e6a1000000000000000000000000db9cb2478d917719c53862008672166808258577", to: _},
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
               %{data: "0x9ea8082b000000000000000000000000db9cb2478d917719c53862008672166808258577", to: _},
               "latest"
             ]
           } ->
             %{
               id: id,
               result:
                 "0x00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000001000000000000000000000000f3e77c4af5eb2f33afff7619d8d1e751d718a491"
             }

           # stakeAmountTotalMinusOrderedWithdraw
           %{
             id: id,
             method: "eth_call",
             params: [
               %{data: "0x234fbf2b000000000000000000000000db9cb2478d917719c53862008672166808258577", to: _},
               "latest"
             ]
           } ->
             %{
               id: id,
               result: "0x00000000000000000000000000000000000000000000000029a2241af62c0000"
             }

           # stakeAmountMinusOrderedWithdraw
           %{
             id: id,
             jsonrpc: "2.0",
             method: "eth_call",
             params: [
               %{
                 data:
                   "0x58daab6a000000000000000000000000db9cb2478d917719c53862008672166808258577000000000000000000000000db9cb2478d917719c53862008672166808258577",
                 to: _
               },
               "latest"
             ]
           } ->
             %{
               id: id,
               result: "0x0000000000000000000000000000000000000000000000001bc16d674ec80000"
             }

           # isValidator
           %{
             id: id,
             method: "eth_call",
             params: [
               %{data: "0xfacd743b000000000000000000000000be69eb0968226a1808975e1a1f2127667f2bffb3", to: _},
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
               %{data: "0xb41832e4000000000000000000000000be69eb0968226a1808975e1a1f2127667f2bffb3", to: _},
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
               %{data: "0xa92252ae000000000000000000000000be69eb0968226a1808975e1a1f2127667f2bffb3", to: _},
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
               %{data: "0x5836d08a000000000000000000000000be69eb0968226a1808975e1a1f2127667f2bffb3", to: _},
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
               %{data: "0x1d0cd4c6000000000000000000000000be69eb0968226a1808975e1a1f2127667f2bffb3", to: _},
               "latest"
             ]
           } ->
             %{
               id: id,
               result: "0x0000000000000000000000000000000000000000000000000000000000000000"
             }

           # DELEGATOR
           # stakeAmount
           %{
             id: id,
             method: "eth_call",
             params: [
               %{
                 data:
                   "0xa697ecff000000000000000000000000db9cb2478d917719c53862008672166808258577000000000000000000000000f3e77c4af5eb2f33afff7619d8d1e751d718a491",
                 to: _
               },
               "latest"
             ]
           } ->
             %{
               id: id,
               result: "0x0000000000000000000000000000000000000000000000000de0b6b3a7640000"
             }

           # orderedWithdrawAmount
           %{
             id: id,
             method: "eth_call",
             params: [
               %{
                 data:
                   "0xe9ab0300000000000000000000000000db9cb2478d917719c53862008672166808258577000000000000000000000000f3e77c4af5eb2f33afff7619d8d1e751d718a491",
                 to: _
               },
               "latest"
             ]
           } ->
             %{
               id: id,
               result: "0x0000000000000000000000000000000000000000000000000000000000000000"
             }

           # maxWithdrawAllowed
           %{
             id: id,
             method: "eth_call",
             params: [
               %{
                 data:
                   "0x6bda1577000000000000000000000000db9cb2478d917719c53862008672166808258577000000000000000000000000f3e77c4af5eb2f33afff7619d8d1e751d718a491",
                 to: _
               },
               "latest"
             ]
           } ->
             %{
               id: id,
               result: "0x0000000000000000000000000000000000000000000000000de0b6b3a7640000"
             }

           # maxWithdrawOrderAllowed
           %{
             id: id,
             method: "eth_call",
             params: [
               %{
                 data:
                   "0x950a6513000000000000000000000000db9cb2478d917719c53862008672166808258577000000000000000000000000f3e77c4af5eb2f33afff7619d8d1e751d718a491",
                 to: _
               },
               "latest"
             ]
           } ->
             %{
               id: id,
               result: "0x0000000000000000000000000000000000000000000000000de0b6b3a7640000"
             }

           # orderWithdrawEpoch
           %{
             id: id,
             method: "eth_call",
             params: [
               %{
                 data:
                   "0xa4205967000000000000000000000000db9cb2478d917719c53862008672166808258577000000000000000000000000f3e77c4af5eb2f33afff7619d8d1e751d718a491",
                 to: _
               },
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
