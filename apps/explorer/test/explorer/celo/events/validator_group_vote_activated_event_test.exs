defmodule Explorer.Celo.Events.ValidatorGroupVoteActivatedEventTest do
  use ExUnit.Case, async: true

  alias Explorer.Chain.Log
  alias Explorer.Celo.ContractEvents.EventTransformer
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

    test "converts from ethjsonrpc log to event type" do
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
    end
  end
end
