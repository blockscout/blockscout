# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Indexer.Fetcher.Celo.EpochBlockOperations.ValidatorAndGroupPaymentsPostL2MigrationTest do
  use Explorer.DataCase

  use Utils.CompileTimeEnvHelper, chain_identity: [:explorer, :chain_identity]

  if @chain_identity == {:optimism, :celo} do
    import ExUnit.CaptureLog, only: [capture_log: 1]

    alias Explorer.Chain.Celo.Epoch
    alias Explorer.Utility.LogFirstTopic
    alias Indexer.Fetcher.Celo.EpochBlockOperations.ValidatorAndGroupPaymentsPostL2Migration

    @validator_epoch_payment_distributed_event_topic "0xee2788e7abedfc61d9608e143b172de1a608a4298b06ed8c84838aa0ad6bd136"

    describe "fetch/1" do
      test "aborts when the block has `ValidatorEpochPaymentDistributed` logs stored in the optimized format" do
        # logs without `address_hash` and `first_topic` are found by `address_id`
        # and `first_topic_id` only once the migration is started
        set_fill_logs_optimized_fields_migration_started()

        epoch_manager = insert(:address)

        old_env = Application.get_env(:explorer, :celo)

        Application.put_env(
          :explorer,
          :celo,
          Keyword.merge(old_env || [], epoch_manager_contract_address: to_string(epoch_manager.hash))
        )

        on_exit(fn -> Application.put_env(:explorer, :celo, old_env) end)

        block = insert(:block)

        # epoch logs are not linked to a transaction; since v12 `address_hash` and
        # `first_topic` are kept only in `address_id` and `first_topic_id`
        insert(:log,
          block: block,
          block_number: block.number,
          transaction: nil,
          transaction_hash: nil,
          transaction_index: nil,
          address: epoch_manager,
          address_hash: nil,
          first_topic: nil,
          first_topic_id: LogFirstTopic.find_or_create(@validator_epoch_payment_distributed_event_topic).id
        )

        epoch = %Epoch{number: 1, start_processing_block: block}

        # the event is checked before any request to the node
        assert capture_log(fn ->
                 assert {:error, "Validator payment distributed event exists"} =
                          ValidatorAndGroupPaymentsPostL2Migration.fetch(epoch)
               end) =~ "Validator payment distributed event exists"
      end
    end
  end
end
