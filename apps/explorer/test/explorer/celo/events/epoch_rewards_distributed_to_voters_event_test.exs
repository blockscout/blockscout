defmodule Explorer.Celo.Events.EpochRewardsDistributedToVotersEventTest do
  use ExUnit.Case, async: true

  alias Explorer.Chain.Log
  alias Explorer.Celo.ContractEvents.EventTransformer
  alias Explorer.Celo.ContractEvents.Election.EpochRewardsDistributedToVotersEvent

  describe "Test conversion" do
    test "converts from db log to concrete event type" do
      test_log = %Explorer.Chain.Log{
        address_hash: %Explorer.Chain.Hash{
          byte_count: 20,
          bytes: <<141, 102, 119, 25, 33, 68, 41, 40, 112, 144, 126, 63, 168, 165, 82, 127, 229, 90, 127, 246>>
        },
        block_hash: %Explorer.Chain.Hash{
          byte_count: 32,
          bytes:
            <<254, 191, 217, 63, 241, 142, 215, 218, 49, 254, 129, 108, 56, 249, 72, 220, 12, 207, 160, 12, 108, 157,
              106, 108, 17, 51, 158, 153, 118, 182, 255, 64>>
        },
        block_number: 11_111_040,
        data: %Explorer.Chain.Data{
          bytes:
            <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 22, 80, 90, 116, 216, 163, 248, 180,
              104>>
        },
        first_topic: "0x91ba34d62474c14d6c623cd322f4256666c7a45b7fdaa3378e009d39dfcec2a7",
        fourth_topic: nil,
        index: 573,
        second_topic: "0x000000000000000000000000b33e9e01e561a1da60f7cb42508500e571afb6eb",
        third_topic: nil,
        transaction_hash: nil,
        type: nil
      }

      result = %EpochRewardsDistributedToVotersEvent{} |> EventTransformer.from_log(test_log)

      assert result.value == 411_618_438_366_361_072_744
      assert to_string(result.group) == "0xb33e9e01e561a1da60f7cb42508500e571afb6eb"
      assert result.log_index == 573
    end
  end
end
