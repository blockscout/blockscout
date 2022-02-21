alias Explorer.Celo.ContractEvents.Election

alias Election.{
  EpochRewardsDistributedToVotersEvent,
  ValidatorGroupActiveVoteRevokedEvent,
  ValidatorGroupVoteActivatedEvent
}

alias Explorer.Chain.{Address, Hash}

import Explorer.Factory

defmodule Explorer.SetupVoterRewardsTest do
  def setup_for_group do
    validator_group_active_vote_revoked = ValidatorGroupActiveVoteRevokedEvent.name()
    %Address{hash: voter_address_1_hash} = insert(:address)
    %Address{hash: voter_address_2_hash} = insert(:address)
    %Address{hash: group_address_hash} = insert(:address)
    %Address{hash: contract_address_hash} = insert(:address)

    block_1 = insert(:block, number: 10_692_863, timestamp: ~U[2022-01-01 13:08:43.162804Z])
    log_1 = insert(:log, block: block_1)

    # voter_1 activates votes for group_1 on January 1st and is the only voter
    insert(:contract_event, %{
      event: %ValidatorGroupVoteActivatedEvent{
        block_hash: block_1.hash,
        log_index: log_1.index,
        account: voter_address_1_hash,
        contract_address_hash: contract_address_hash,
        group: group_address_hash,
        units: 1000,
        value: 650
      }
    })

    block_2 = insert(:block, number: 10_727_421, timestamp: ~U[2022-01-03 13:08:43.162804Z])
    log_2 = insert(:log, block: block_2)

    # voter_2 activates votes for group_1 on January 3rd
    insert(:contract_event, %{
      event: %ValidatorGroupVoteActivatedEvent{
        block_hash: block_2.hash,
        log_index: log_2.index,
        account: voter_address_2_hash,
        contract_address_hash: contract_address_hash,
        group: group_address_hash,
        units: 1000,
        value: 250
      }
    })

    block_3 = insert(:block, number: 10_744_696, timestamp: ~U[2022-01-04 13:08:43.162804Z])
    log_3 = insert(:log, block: block_3)

    # voter_1 revokes votes for group_1 on January 4th
    insert(:contract_event, %{
      event: %ValidatorGroupActiveVoteRevokedEvent{
        block_hash: block_3.hash,
        log_index: log_3.index,
        account: voter_address_1_hash,
        contract_address_hash: contract_address_hash,
        group: group_address_hash,
        units: 1000,
        value: 650
      }
    })

    block_4 = insert(:block, number: 10_761_966, timestamp: ~U[2022-01-05 13:08:43.162804Z])
    log_4 = insert(:log, block: block_4)

    # voter_2 revokes votes for group_1 on January 5th
    insert(:contract_event, %{
      event: %ValidatorGroupActiveVoteRevokedEvent{
        block_hash: block_4.hash,
        log_index: log_4.index,
        account: voter_address_2_hash,
        contract_address_hash: contract_address_hash,
        group: group_address_hash,
        units: 1000,
        value: 324
      }
    })

    block_5 = insert(:block, number: 10_796_524, timestamp: ~U[2022-01-07 13:08:43.162804Z])
    log_5 = insert(:log, block: block_5)

    # voter_1 revokes votes for group_1 on January 7th
    insert(:contract_event, %{
      event: %ValidatorGroupActiveVoteRevokedEvent{
        block_hash: block_5.hash,
        log_index: log_5.index,
        account: voter_address_1_hash,
        contract_address_hash: contract_address_hash,
        group: group_address_hash,
        units: 1000,
        value: 350
      }
    })

    block_6 =
      insert(
        :block,
        hash: %Hash{
          byte_count: 32,
          bytes: <<1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1>>
        },
        number: 10_696_320,
        timestamp: ~U[2022-01-01 17:42:43.162804Z]
      )

    log_6 = insert(:log, block: block_6)

    insert(:celo_validator_group_votes, %{
      block_hash: block_6.hash,
      group_hash: group_address_hash,
      previous_block_active_votes: 650
    })

    insert(:contract_event, %{
      event: %EpochRewardsDistributedToVotersEvent{
        block_hash: block_6.hash,
        log_index: log_6.index,
        contract_address_hash: contract_address_hash,
        group: group_address_hash,
        value: 80
      }
    })

    block_7 =
      insert(
        :block,
        hash: %Hash{
          byte_count: 32,
          bytes: <<1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2>>
        },
        number: 10_713_600,
        timestamp: ~U[2022-01-02 17:42:43.162804Z]
      )

    log_7 = insert(:log, block: block_7)

    insert(:celo_validator_group_votes, %{
      block_hash: block_7.hash,
      group_hash: group_address_hash,
      previous_block_active_votes: 730
    })

    insert(:contract_event, %{
      event: %EpochRewardsDistributedToVotersEvent{
        block_hash: block_7.hash,
        log_index: log_7.index,
        contract_address_hash: contract_address_hash,
        group: group_address_hash,
        value: 20
      }
    })

    block_8 =
      insert(
        :block,
        hash: %Hash{
          byte_count: 32,
          bytes: <<1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3>>
        },
        number: 10_730_880,
        timestamp: ~U[2022-01-03 17:42:43.162804Z]
      )

    log_8 = insert(:log, block: block_8)

    insert(:celo_validator_group_votes, %{
      block_hash: block_8.hash,
      group_hash: group_address_hash,
      previous_block_active_votes: 1000
    })

    insert(:contract_event, %{
      event: %EpochRewardsDistributedToVotersEvent{
        block_hash: block_8.hash,
        log_index: log_8.index,
        contract_address_hash: contract_address_hash,
        group: group_address_hash,
        value: 100
      }
    })

    block_9 =
      insert(
        :block,
        hash: %Hash{
          byte_count: 32,
          bytes: <<1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 4>>
        },
        number: 10_748_160,
        timestamp: ~U[2022-01-04 17:42:43.162804Z]
      )

    log_9 = insert(:log, block: block_9)

    insert(:celo_validator_group_votes, %{
      block_hash: block_9.hash,
      group_hash: group_address_hash,
      previous_block_active_votes: 450
    })

    insert(:contract_event, %{
      event: %EpochRewardsDistributedToVotersEvent{
        block_hash: block_9.hash,
        log_index: log_9.index,
        contract_address_hash: contract_address_hash,
        group: group_address_hash,
        value: 80
      }
    })

    block_10 =
      insert(
        :block,
        hash: %Hash{
          byte_count: 32,
          bytes: <<1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5>>
        },
        number: 10_765_440,
        timestamp: ~U[2022-01-05 17:42:43.162804Z]
      )

    log_10 = insert(:log, block: block_10)

    insert(:celo_validator_group_votes, %{
      block_hash: block_10.hash,
      group_hash: group_address_hash,
      previous_block_active_votes: 206
    })

    insert(:contract_event, %{
      event: %EpochRewardsDistributedToVotersEvent{
        block_hash: block_10.hash,
        log_index: log_10.index,
        contract_address_hash: contract_address_hash,
        group: group_address_hash,
        value: 77
      }
    })

    block_11 =
      insert(
        :block,
        hash: %Hash{
          byte_count: 32,
          bytes: <<1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 6>>
        },
        number: 10_782_720,
        timestamp: ~U[2022-01-06 17:42:43.162804Z]
      )

    log_11 = insert(:log, block: block_11)

    insert(:celo_validator_group_votes, %{
      block_hash: block_11.hash,
      group_hash: group_address_hash,
      previous_block_active_votes: 283
    })

    insert(:contract_event, %{
      event: %EpochRewardsDistributedToVotersEvent{
        block_hash: block_11.hash,
        log_index: log_11.index,
        contract_address_hash: contract_address_hash,
        group: group_address_hash,
        value: 67
      }
    })

    {voter_address_1_hash, group_address_hash}
  end

  def setup_for_all_groups do
    %Address{hash: voter_address_1_hash} = insert(:address)
    %Address{hash: voter_address_2_hash} = insert(:address)
    %Address{hash: contract_address_hash} = insert(:address)

    %Address{hash: group_address_1_hash} =
      insert(:address,
        hash: %Explorer.Chain.Hash{
          byte_count: 20,
          bytes: <<1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1>>
        }
      )

    %Address{hash: group_address_2_hash} =
      insert(:address,
        hash: %Explorer.Chain.Hash{
          byte_count: 20,
          bytes: <<1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2>>
        }
      )

    block_1 = insert(:block, number: 10_692_863, timestamp: ~U[2022-01-01 13:08:43.162804Z])
    log_1 = insert(:log, block: block_1)

    insert(:contract_event, %{
      event: %ValidatorGroupVoteActivatedEvent{
        block_hash: block_1.hash,
        log_index: log_1.index,
        account: voter_address_1_hash,
        contract_address_hash: contract_address_hash,
        group: group_address_1_hash,
        units: 1000,
        value: 650
      }
    })

    block_2 = insert(:block, number: 10_744_703, timestamp: ~U[2022-01-04 13:08:43.162804Z])
    log_2 = insert(:log, block: block_2)

    insert(:contract_event, %{
      event: %ValidatorGroupVoteActivatedEvent{
        block_hash: block_2.hash,
        log_index: log_2.index,
        account: voter_address_1_hash,
        contract_address_hash: contract_address_hash,
        group: group_address_2_hash,
        units: 1000,
        value: 250
      }
    })

    block_3 = insert(:block, number: 10_779_263, timestamp: ~U[2022-01-06 13:08:43.162804Z])
    log_3 = insert(:log, block: block_3)

    insert(:contract_event, %{
      event: %ValidatorGroupVoteActivatedEvent{
        block_hash: block_3.hash,
        log_index: log_3.index,
        account: voter_address_2_hash,
        contract_address_hash: contract_address_hash,
        group: group_address_1_hash,
        units: 1000,
        value: 650
      }
    })

    {voter_address_1_hash, group_address_1_hash, group_address_2_hash}
  end
end
