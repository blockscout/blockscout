defmodule Explorer.Celo.ContractEvents.EventMapTest do
  use Explorer.DataCase, async: true

  alias Explorer.Celo.ContractEvents.Election.ValidatorGroupActiveVoteRevokedEvent
  alias Explorer.Celo.ContractEvents.EventMap
  alias Explorer.Repo

  describe "event map" do
    test "Gets struct for topic" do
      result =
        "0x45aac85f38083b18efe2d441a65b9c1ae177c78307cb5a5d4aec8f7dbcaeabfe"
        |> EventMap.event_for_topic()

      assert result.name == "ValidatorGroupVoteActivated"
    end

    test "Gets struct for name" do
      result =
        "ValidatorGroupVoteActivated"
        |> EventMap.event_for_name()

      assert result.topic == "0x45aac85f38083b18efe2d441a65b9c1ae177c78307cb5a5d4aec8f7dbcaeabfe"
    end

    test "Converts jsonrpc log format to CeloContractEvent changeset params" do
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

      [result] = EventMap.rpc_to_event_params([test_params])

      assert result.name == "ValidatorGroupVoteActivated"
      assert result.log_index == 8

      assert result.transaction_hash |> to_string() ==
               "0xb8960575a898afa8a124cd7414f1261109a119dba3bed4489393952a1556a5f0"

      assert result.contract_address_hash |> to_string() == "0x765de816845861e75a25fca122bb6898b8b1282a"
      assert result.block_hash |> to_string() == "0x42b21f09e9956d1a01195b1ca461059b2705fe850fc1977bd7182957e1b390d3"

      %{params: params} = result

      assert params.value == 66_980_000_000_000_000_000
      assert params.units == 6_136_281_451_163_456_507_329_304_650_157_103_347_504
      assert params.account == "\\x88c1c759600ec3110af043c183a2472ab32d099c"
      assert params.group == "\\x47b2db6af05a55d42ed0f3731735f9479abf0673"
    end
  end

  describe "test event factory " do
    test "Asserts factory functionality for events" do
      block = insert(:block)
      log = insert(:log, block: block)
      contract = insert(:contract_address)

      event = %ValidatorGroupActiveVoteRevokedEvent{
        block_hash: block.hash,
        log_index: log.index,
        contract_address_hash: contract.hash,
        account: address_hash(),
        group: address_hash(),
        units: 6_969_696_969,
        value: 420_420_420
      }

      insert(:contract_event, %{event: event})

      events =
        ValidatorGroupActiveVoteRevokedEvent.query() |> Repo.all() |> EventMap.celo_contract_event_to_concrete_event()

      assert length(events) == 1

      [result] = events
      assert result.units == 6_969_696_969
      assert result.value == 420_420_420
    end
  end
end
