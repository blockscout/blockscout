defmodule Explorer.Celo.Events.ValidatorGroupVoteActivatedEventTest do
  use Explorer.DataCase, async: true

  alias Explorer.Chain.CeloContractEvent
  alias Explorer.Chain.{Address, Block, Log}
  alias Explorer.Celo.ContractEvents.EventTransformer
  alias Explorer.Celo.ContractEvents.EventMap
  alias Explorer.Celo.ContractEvents.Election.ValidatorGroupVoteActivatedEvent

  describe "Test conversion" do
    test "converts from db log to concrete event type" do
      test_log = %Log{
        first_topic: "0x45aac85f38083b18efe2d441a65b9c1ae177c78307cb5a5d4aec8f7dbcaeabfe",
        fourth_topic: nil,
        index: 8,
        second_topic: "0x00000000000000000000000088c1c759600ec3110af043c183a2472ab32d099c",
        third_topic: "0x00000000000000000000000047b2db6af05a55d42ed0f3731735f9479abf0673",
        transaction_hash: %Explorer.Chain.Hash{
          byte_count: 32,
          bytes:
            <<51, 29, 185, 3, 161, 229, 18, 118, 203, 232, 19, 53, 6, 69, 194, 216, 184, 147, 82, 253, 153, 80, 89, 61,
              16, 26, 146, 28, 159, 122, 17, 82>>
        },
        type: nil,
        block_number: 10_913_664,
        data: %Explorer.Chain.Data{
          bytes:
            <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3, 161, 136, 195, 31, 239, 170, 0, 0,
              0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 18, 8, 108, 209, 196, 23, 97, 135, 112, 147, 87, 144, 173,
              113, 77, 119, 48>>
        },
        block_hash: %Explorer.Chain.Hash{
          byte_count: 32,
          bytes:
            <<39, 45, 177, 52, 77, 35, 177, 94, 225, 112, 13, 8, 78, 175, 197, 158, 167, 36, 208, 58, 41, 172, 144, 114,
              90, 101, 80, 42, 78, 59, 143, 220>>
        },
        address_hash: %Explorer.Chain.Hash{
          byte_count: 20,
          bytes: <<141, 102, 119, 25, 33, 68, 41, 40, 112, 144, 126, 63, 168, 165, 82, 127, 229, 90, 127, 246>>
        }
      }

      result = %ValidatorGroupVoteActivatedEvent{} |> EventTransformer.from_log(test_log)

      assert result.value == 66_980_000_000_000_000_000
      assert result.units == 6_136_281_451_163_456_507_329_304_650_157_103_347_504
      assert to_string(result.account) == "0x88c1c759600ec3110af043c183a2472ab32d099c"
      assert to_string(result.group) == "0x47b2db6af05a55d42ed0f3731735f9479abf0673"
      assert result.log_index == 8
    end

    test "converts from ethjsonrpc log to event type and insert into db" do
      {:ok, hsh} = Explorer.Chain.Hash.Full.cast("0x42b21f09e9956d1a01195b1ca461059b2705fe850fc1977bd7182957e1b390d3")
      insert(:block, hash: hsh)

      {:ok, hsh} = Explorer.Chain.Hash.Full.cast("0xb8960575a898afa8a124cd7414f1261109a119dba3bed4489393952a1556a5f0")
      insert(:transaction, hash: hsh)

      {:ok, add} = Explorer.Chain.Hash.Address.cast("0x765de816845861e75a25fca122bb6898b8b1282a")
      insert(:core_contract, address_hash: add)

      test_params = %{
        address_hash: "0x765de816845861e75a25fca122bb6898b8b1282a",
        block_hash: "0x42b21f09e9956d1a01195b1ca461059b2705fe850fc1977bd7182957e1b390d3",
        block_number: 10_913_664,
        data:
          "0x000000000000000000000000000000000000000000000003a188c31fefaa000000000000000000000000000000000012086cd1c417618770935790ad714d7730",
        first_topic: "0x45aac85f38083b18efe2d441a65b9c1ae177c78307cb5a5d4aec8f7dbcaeabfe",
        fourth_topic: nil,
        index: 8,
        second_topic: "0x00000000000000000000000088c1c759600ec3110af043c183a2472ab32d099c",
        third_topic: "0x00000000000000000000000047b2db6af05a55d42ed0f3731735f9479abf0673",
        transaction_hash: "0xb8960575a898afa8a124cd7414f1261109a119dba3bed4489393952a1556a5f0"
      }

      result = %ValidatorGroupVoteActivatedEvent{} |> EventTransformer.from_params(test_params)

      assert result.value == 66_980_000_000_000_000_000
      assert result.units == 6_136_281_451_163_456_507_329_304_650_157_103_347_504
      assert result.account |> to_string() == "0x88c1c759600ec3110af043c183a2472ab32d099c"
      assert result.group |> to_string() == "0x47b2db6af05a55d42ed0f3731735f9479abf0673"
      assert result.log_index == 8

      # explictly setting timestamps as insert_all doesn't do this
      r =
        result
        |> EventMap.event_to_contract_event_params()
        |> Map.put(:inserted_at, Timex.now())
        |> Map.put(:updated_at, Timex.now())

      {1, _} = Explorer.Repo.insert_all(CeloContractEvent, [r])

      [result] =
        ValidatorGroupVoteActivatedEvent.query()
        |> Repo.all()
        |> EventMap.celo_contract_event_to_concrete_event()

      assert result.value == 66_980_000_000_000_000_000
      assert result.units == 6_136_281_451_163_456_507_329_304_650_157_103_347_504
      assert result.account |> to_string() == "0x88c1c759600ec3110af043c183a2472ab32d099c"
      assert result.group |> to_string() == "0x47b2db6af05a55d42ed0f3731735f9479abf0673"
      assert result.log_index == 8

      {:ok, account} = Explorer.Chain.Hash.Address.cast("0x88c1c759600ec3110af043c183a2472ab32d099c")

      # test dynamic query methods
      [account_query_result] =
        ValidatorGroupVoteActivatedEvent.query()
        |> ValidatorGroupVoteActivatedEvent.query_by_account(account)
        |> EventMap.query_all()

      assert result == account_query_result
    end
  end

  describe "get_previous_epoch_voters_and_groups/1" do
    test "returns accounts that have activated votes for groups" do
      %Address{hash: voter_1_address_hash} = insert(:address)
      %Address{hash: group_1_address_hash} = insert(:address)
      %Address{hash: voter_2_address_hash} = insert(:address)
      %Address{hash: group_2_address_hash} = insert(:address)
      %Explorer.Chain.CeloCoreContract{address_hash: contract_address_hash} = insert(:core_contract)

      block_1 = insert(:block, number: 10_692_863, timestamp: ~U[2022-01-01 13:08:43.162804Z])
      log_1 = insert(:log, block: block_1)

      insert(:contract_event, %{
        event: %ValidatorGroupVoteActivatedEvent{
          block_number: block_1.number,
          log_index: log_1.index,
          account: voter_1_address_hash,
          contract_address_hash: contract_address_hash,
          group: group_1_address_hash,
          units: 1000,
          value: 650
        }
      })

      block_2 = insert(:block, number: 10_710_143, timestamp: ~U[2022-01-02 13:08:43.162814Z])
      log_2 = insert(:log, block: block_2)

      insert(:contract_event, %{
        event: %ValidatorGroupVoteActivatedEvent{
          block_number: block_2.number,
          log_index: log_2.index,
          account: voter_2_address_hash,
          contract_address_hash: contract_address_hash,
          group: group_2_address_hash,
          units: 1000,
          value: 650
        }
      })

      assert ValidatorGroupVoteActivatedEvent.get_account_group_pairs_with_activated_votes(10_696_320) ==
               [
                 %{
                   account_hash: voter_1_address_hash,
                   group_hash: group_1_address_hash
                 }
               ]
    end
  end
end
