# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Indexer.Fetcher.Celo.EpochBlockOperations.ValidatorAndGroupPaymentsPriorL2MigrationTest do
  use Explorer.DataCase

  use Utils.CompileTimeEnvHelper, chain_identity: [:explorer, :chain_identity]

  if @chain_identity == {:optimism, :celo} do
    alias Explorer.Chain.Cache.CeloCoreContracts
    alias Explorer.Chain.Celo.Epoch
    alias Explorer.Chain.Hash
    alias Explorer.Utility.LogFirstTopic
    alias Indexer.Fetcher.Celo.EpochBlockOperations.ValidatorAndGroupPaymentsPriorL2Migration
    alias Indexer.Transform.Celo.ValidatorEpochPaymentDistributions

    setup do
      old_env = Application.get_env(:explorer, CeloCoreContracts, [])
      validators_contract = insert(:address)

      Application.put_env(
        :explorer,
        CeloCoreContracts,
        Keyword.merge(old_env,
          contracts: %{
            "addresses" => %{
              "Validators" => [
                %{"address" => to_string(validators_contract.hash), "updated_at_block_number" => 0}
              ]
            }
          }
        )
      )

      on_exit(fn -> Application.put_env(:explorer, CeloCoreContracts, old_env) end)

      %{validators_contract: validators_contract}
    end

    describe "fetch/1" do
      test "parses payments from logs stored in the optimized format", %{validators_contract: validators_contract} do
        # logs without `address_hash` and `first_topic` are found by `address_id`
        # and `first_topic_id` only once the migration is started
        set_fill_logs_optimized_fields_migration_started()

        block = insert(:block)
        %{hash: validator_address_hash} = insert(:address)
        %{hash: group_address_hash} = insert(:address)

        # epoch logs are not linked to a transaction; since v12 `address_hash`,
        # `first_topic` and `data` are kept only in `address_id`,
        # `first_topic_id` and `compressed_data`
        insert(:log,
          block: block,
          block_number: block.number,
          transaction: nil,
          transaction_hash: nil,
          transaction_index: nil,
          address: validators_contract,
          address_hash: nil,
          first_topic: nil,
          first_topic_id: LogFirstTopic.find_or_create(ValidatorEpochPaymentDistributions.signature()).id,
          second_topic: zero_padded(validator_address_hash),
          third_topic: zero_padded(group_address_hash),
          data: nil,
          compressed_data: "0x" <> Base.encode16(ABI.encode("(uint256,uint256)", [{123, 456}]), case: :lower)
        )

        epoch = %Epoch{number: 1, start_processing_block: block}

        assert {:ok,
                [
                  %{
                    epoch_number: 1,
                    type: :validator,
                    account_address_hash: ^validator_address_hash,
                    associated_account_address_hash: ^group_address_hash,
                    amount: 123
                  },
                  %{
                    epoch_number: 1,
                    type: :group,
                    account_address_hash: ^group_address_hash,
                    associated_account_address_hash: ^validator_address_hash,
                    amount: 456
                  }
                ]} = ValidatorAndGroupPaymentsPriorL2Migration.fetch(epoch)
      end
    end

    defp zero_padded(address_hash) do
      "0x" <> hash_string = Hash.to_string(address_hash)
      "0x000000000000000000000000" <> hash_string
    end
  end
end
