defmodule Explorer.SetupValidatorAndGroupRewardsTest do
  alias Explorer.Celo.ContractEvents.Validators.ValidatorEpochPaymentDistributedEvent
  alias Explorer.Chain.{Address, Block}

  import Explorer.Factory

  def setup do
    %Address{hash: validator_address_1_hash} = insert(:address)
    %Address{hash: validator_address_2_hash} = insert(:address)
    %Address{hash: group_address_1_hash} = insert(:address)
    %Address{hash: group_address_2_hash} = insert(:address)
    %Address{hash: contract_address_hash} = insert(:address)

    %Block{hash: block_1_hash} =
      block_1 = insert(:block, number: 10_696_320, timestamp: ~U[2022-01-01 17:42:43.162804Z])

    log_1 = insert(:log, block: block_1)

    insert(:contract_event, %{
      event: %ValidatorEpochPaymentDistributedEvent{
        block_number: 10_696_320,
        contract_address_hash: contract_address_hash,
        log_index: log_1.index,
        validator: validator_address_1_hash,
        validator_payment: 100_000,
        group: group_address_1_hash,
        group_payment: 300_000
      }
    })

    %Block{hash: block_2_hash} =
      block_2 = insert(:block, number: 10_730_880, timestamp: ~U[2022-01-03 17:42:43.162804Z])

    log_2 = insert(:log, block: block_2)
    log_3 = insert(:log, block: block_2)

    insert(:contract_event, %{
      event: %ValidatorEpochPaymentDistributedEvent{
        block_number: 10_730_880,
        contract_address_hash: contract_address_hash,
        log_index: log_2.index,
        validator: validator_address_1_hash,
        validator_payment: 100_000,
        group: group_address_1_hash,
        group_payment: 300_000
      }
    })

    insert(:contract_event, %{
      event: %ValidatorEpochPaymentDistributedEvent{
        block_number: 10_730_880,
        contract_address_hash: contract_address_hash,
        log_index: log_3.index,
        validator: validator_address_2_hash,
        validator_payment: 100_000,
        group: group_address_2_hash,
        group_payment: 300_000
      }
    })

    %Block{hash: block_3_hash} =
      block_3 = insert(:block, number: 10_748_160, timestamp: ~U[2022-01-04 17:42:43.162804Z])

    log_4 = insert(:log, block: block_3)
    log_5 = insert(:log, block: block_3)

    insert(:contract_event, %{
      event: %ValidatorEpochPaymentDistributedEvent{
        block_number: 10_748_160,
        contract_address_hash: contract_address_hash,
        log_index: log_4.index,
        validator: validator_address_1_hash,
        validator_payment: 200_000,
        group: group_address_1_hash,
        group_payment: 400_000
      }
    })

    insert(:contract_event, %{
      event: %ValidatorEpochPaymentDistributedEvent{
        block_number: 10_748_160,
        contract_address_hash: contract_address_hash,
        log_index: log_5.index,
        validator: validator_address_2_hash,
        validator_payment: 200_000,
        group: group_address_2_hash,
        group_payment: 400_000
      }
    })

    {validator_address_1_hash, group_address_1_hash, block_2_hash, block_3_hash}
  end
end
