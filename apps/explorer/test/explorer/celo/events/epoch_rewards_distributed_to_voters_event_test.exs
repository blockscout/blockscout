defmodule Explorer.Celo.Events.EpochRewardsDistributedToVotersEventTest do
  use Explorer.DataCase

  alias Explorer.Chain.{Address, Log}
  alias Explorer.Celo.ContractEvents.EventTransformer
  alias Explorer.Celo.ContractEvents.Election.{EpochRewardsDistributedToVotersEvent, ValidatorGroupVoteActivatedEvent}

  import Explorer.Factory

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

  describe "elected_groups_for_block/1" do
    test "fetches validator group hashes for a block hash" do
      block_1 = insert(:block, number: 172_800)
      log_1_1 = insert(:log, block: block_1, index: 1)
      log_1_2 = insert(:log, block: block_1, index: 2)
      log_1_3 = insert(:log, block: block_1, index: 3)
      block_2 = insert(:block, number: 190_080)
      log_2 = insert(:log, block: block_2, index: 1)
      %Address{hash: group_address_1_hash} = insert(:address)
      %Address{hash: group_address_2_hash} = insert(:address)
      %Address{hash: contract_address_hash} = insert(:address)

      insert(:contract_event, %{
        event: %EpochRewardsDistributedToVotersEvent{
          block_number: 172_800,
          log_index: log_1_1.index,
          contract_address_hash: contract_address_hash,
          group: group_address_1_hash,
          value: 650
        }
      })

      insert(:contract_event, %{
        event: %ValidatorGroupVoteActivatedEvent{
          block_number: 172_800,
          log_index: log_1_2.index,
          account: group_address_1_hash,
          contract_address_hash: contract_address_hash,
          group: group_address_1_hash,
          units: 10000,
          value: 650
        }
      })

      insert(:contract_event, %{
        event: %EpochRewardsDistributedToVotersEvent{
          block_number: 172_800,
          log_index: log_1_3.index,
          contract_address_hash: contract_address_hash,
          group: group_address_2_hash,
          value: 650
        }
      })

      insert(:contract_event, %{
        event: %EpochRewardsDistributedToVotersEvent{
          block_number: 190_080,
          log_index: log_2.index,
          contract_address_hash: contract_address_hash,
          group: group_address_2_hash,
          value: 650
        }
      })

      assert EpochRewardsDistributedToVotersEvent.elected_groups_for_block(block_1.number) == [
               group_address_1_hash,
               group_address_2_hash
             ]
    end
  end
end
