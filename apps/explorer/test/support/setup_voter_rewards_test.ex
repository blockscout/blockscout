defmodule Explorer.SetupVoterRewardsTest do
  alias Explorer.Celo.ContractEvents.Election

  alias Election.{
    ValidatorGroupActiveVoteRevokedEvent,
    ValidatorGroupVoteActivatedEvent
  }

  alias Explorer.Chain.{Address, Block, Hash}

  import Explorer.Factory

  def setup_for_group do
    %Address{hash: voter_hash} = insert(:address)
    %Address{hash: group_hash} = insert(:address)
    %Explorer.Chain.CeloCoreContract{address_hash: contract_address_hash} = insert(:core_contract)

    block_1_number = 619 * 17_280 - 1
    block_1 = insert(:block, number: block_1_number, timestamp: ~U[2022-01-01 17:42:38.162804Z])
    log_1 = insert(:log, block: block_1)

    insert(:contract_event, %{
      event: %ValidatorGroupVoteActivatedEvent{
        block_number: block_1_number,
        log_index: log_1.index,
        account: voter_hash,
        contract_address_hash: contract_address_hash,
        group: group_hash,
        units: 1000,
        value: 650
      }
    })

    block_2_number = 619 * 17_280

    %Block{hash: block_2_hash} =
      block_2 = insert(:block, number: block_2_number, timestamp: ~U[2022-01-01 17:42:43.162804Z])

    insert(
      :celo_voter_votes,
      account_hash: voter_hash,
      active_votes: Decimal.new(730),
      group_hash: group_hash,
      block_hash: block_2.hash,
      block_number: block_2_number
    )

    block_3_number = 620 * 17_280

    %Block{hash: block_3_hash} =
      block_3 = insert(:block, number: block_3_number, timestamp: ~U[2022-01-02 17:42:43.162804Z])

    insert(
      :celo_voter_votes,
      account_hash: voter_hash,
      active_votes: Decimal.new(750),
      group_hash: group_hash,
      block_hash: block_3.hash,
      block_number: block_3_number
    )

    block_4_number = 621 * 17_280 - 1
    block_4 = insert(:block, number: block_4_number, timestamp: ~U[2022-01-03 17:42:38.162804Z])
    log_4 = insert(:log, block: block_4)

    insert(:contract_event, %{
      event: %ValidatorGroupVoteActivatedEvent{
        block_number: block_4_number,
        log_index: log_4.index,
        account: voter_hash,
        contract_address_hash: contract_address_hash,
        group: group_hash,
        units: 1000,
        value: 250
      }
    })

    block_5_number = 621 * 17_280

    %Block{hash: block_5_hash} =
      block_5 = insert(:block, number: block_5_number, timestamp: ~U[2022-01-03 17:42:43.162804Z])

    insert(
      :celo_voter_votes,
      account_hash: voter_hash,
      active_votes: Decimal.new(1075),
      group_hash: group_hash,
      block_hash: block_5.hash,
      block_number: block_5_number
    )

    block_6_number = 622 * 17_280 - 1
    block_6 = insert(:block, number: block_6_number, timestamp: ~U[2022-01-04 17:42:38.162804Z])
    log_6 = insert(:log, block: block_6)

    insert(:contract_event, %{
      event: %ValidatorGroupActiveVoteRevokedEvent{
        block_number: block_6_number,
        log_index: log_6.index,
        account: voter_hash,
        contract_address_hash: contract_address_hash,
        group: group_hash,
        units: 1000,
        value: 1075
      }
    })

    block_7_number = 622 * 17_280

    %Block{hash: block_7_hash} =
      block_7 = insert(:block, number: block_7_number, timestamp: ~U[2022-01-04 17:42:43.162804Z])

    insert(
      :celo_voter_votes,
      account_hash: voter_hash,
      active_votes: Decimal.new(0),
      group_hash: group_hash,
      block_hash: block_7.hash,
      block_number: block_7_number
    )

    {
      voter_hash,
      group_hash,
      block_2_hash,
      block_3_hash,
      block_5_hash,
      block_7_hash
    }
  end

  def setup_for_all_groups do
    %Address{hash: voter_1_hash} =
      insert(:address,
        hash: %Hash{
          byte_count: 20,
          bytes: <<2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1>>
        }
      )

    %Address{hash: voter_2_hash} =
      insert(:address,
        hash: %Hash{
          byte_count: 20,
          bytes: <<2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2>>
        }
      )

    %Explorer.Chain.CeloCoreContract{address_hash: contract_address_hash} = insert(:core_contract)

    %Address{hash: group_1_hash} =
      insert(:address,
        hash: %Hash{
          byte_count: 20,
          bytes: <<1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1>>
        }
      )

    %Address{hash: group_2_hash} =
      insert(:address,
        hash: %Hash{
          byte_count: 20,
          bytes: <<1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2>>
        }
      )

    block_1 = insert(:block, number: 10_692_863, timestamp: ~U[2022-01-01 13:08:43.162804Z])
    log_1 = insert(:log, block: block_1)

    insert(:contract_event, %{
      event: %ValidatorGroupVoteActivatedEvent{
        block_number: 10_692_863,
        log_index: log_1.index,
        account: voter_1_hash,
        contract_address_hash: contract_address_hash,
        group: group_1_hash,
        units: 1000,
        value: 650
      }
    })

    block_2 = insert(:block, number: 10_744_703, timestamp: ~U[2022-01-04 13:08:43.162804Z])
    log_2 = insert(:log, block: block_2)

    insert(:contract_event, %{
      event: %ValidatorGroupVoteActivatedEvent{
        block_number: 10_744_703,
        log_index: log_2.index,
        account: voter_1_hash,
        contract_address_hash: contract_address_hash,
        group: group_2_hash,
        units: 1000,
        value: 250
      }
    })

    block_3 = insert(:block, number: 10_779_263, timestamp: ~U[2022-01-06 13:08:43.162804Z])
    log_3 = insert(:log, block: block_3)

    insert(:contract_event, %{
      event: %ValidatorGroupVoteActivatedEvent{
        block_number: 10_779_263,
        log_index: log_3.index,
        account: voter_2_hash,
        contract_address_hash: contract_address_hash,
        group: group_1_hash,
        units: 1000,
        value: 650
      }
    })

    {voter_1_hash, group_1_hash, group_2_hash}
  end

  def setup_for_multiple_accounts do
    %Address{hash: voter_1_hash} =
      insert(:address,
        hash: %Hash{
          byte_count: 20,
          bytes: <<2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1>>
        }
      )

    %Address{hash: voter_2_hash} =
      insert(:address,
        hash: %Hash{
          byte_count: 20,
          bytes: <<2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2>>
        }
      )

    %Explorer.Chain.CeloCoreContract{address_hash: contract_address_hash} = insert(:core_contract)

    %Address{hash: group_1_hash} =
      insert(:address,
        hash: %Hash{
          byte_count: 20,
          bytes: <<1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1>>
        }
      )

    %Address{hash: group_2_hash} =
      insert(:address,
        hash: %Hash{
          byte_count: 20,
          bytes: <<1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2>>
        }
      )

    block_1 = insert(:block, number: 10_692_863, timestamp: ~U[2022-01-01 13:08:43.162804Z])
    log_1 = insert(:log, block: block_1)

    insert(:contract_event, %{
      event: %ValidatorGroupVoteActivatedEvent{
        block_number: 10_692_863,
        log_index: log_1.index,
        account: voter_1_hash,
        contract_address_hash: contract_address_hash,
        group: group_1_hash,
        units: 1000,
        value: 650
      }
    })

    block_2 = insert(:block, number: 10_744_703, timestamp: ~U[2022-01-04 13:08:43.162804Z])
    log_2 = insert(:log, block: block_2)

    insert(:contract_event, %{
      event: %ValidatorGroupVoteActivatedEvent{
        block_number: 10_744_703,
        log_index: log_2.index,
        account: voter_1_hash,
        contract_address_hash: contract_address_hash,
        group: group_2_hash,
        units: 1000,
        value: 250
      }
    })

    block_3 = insert(:block, number: 10_761_983, timestamp: ~U[2022-01-05 13:08:43.162804Z])
    log_3 = insert(:log, block: block_3)

    insert(:contract_event, %{
      event: %ValidatorGroupVoteActivatedEvent{
        block_number: 10_761_983,
        log_index: log_3.index,
        account: voter_2_hash,
        contract_address_hash: contract_address_hash,
        group: group_1_hash,
        units: 1000,
        value: 650
      }
    })

    {voter_1_hash, voter_2_hash, group_1_hash, group_2_hash}
  end
end
