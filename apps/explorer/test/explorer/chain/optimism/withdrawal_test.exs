# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Chain.Optimism.WithdrawalTest do
  use Explorer.DataCase

  use Utils.CompileTimeEnvHelper, chain_type: [:explorer, :chain_type]

  if @chain_type == :optimism do
    alias Explorer.Chain.Data
    alias Explorer.Chain.Optimism.Withdrawal
    alias Explorer.Utility.LogFirstTopic

    # MessagePassed(uint256 indexed nonce, address indexed sender, address indexed target, uint256 value, uint256 gasLimit, bytes data, bytes32 withdrawalHash)
    @message_passed_event "0x02a52367d10742d8032712c1bb8e0144ff1ec5ffda1ed7d70bb05a2744955054"

    setup do
      # logs without `first_topic` are joined by `first_topic_id` only once the migration is started
      set_fill_logs_optimized_fields_migration_started()
      :ok
    end

    describe "list/1" do
      test "fills `msg_log_data` of `MessagePassed` logs stored with `compressed_data` only" do
        compressed_log_data = %Data{bytes: <<1, 2, 3>>}
        legacy_log_data = %Data{bytes: <<4, 5, 6>>}

        # imported by v12+: the payload is stored in `compressed_data` only
        insert_withdrawal_with_message_passed_log(1, data: nil, compressed_data: compressed_log_data)
        # not processed by the `fill_logs_compressed_data` migration yet
        insert_withdrawal_with_message_passed_log(2, data: legacy_log_data, compressed_data: nil)

        withdrawals = Withdrawal.list()

        assert [{2, legacy_log_data}, {1, compressed_log_data}] ==
                 Enum.map(withdrawals, &{Decimal.to_integer(&1.msg_nonce), &1.msg_log_data})

        refute Enum.any?(withdrawals, &Map.has_key?(&1, :msg_log_compressed_data))
      end
    end

    describe "transaction_statuses/1" do
      test "fills `msg_log_data` of a `MessagePassed` log stored with `compressed_data` only" do
        compressed_log_data = %Data{bytes: <<1, 2, 3>>}

        transaction =
          insert_withdrawal_with_message_passed_log(1, data: nil, compressed_data: compressed_log_data)

        assert [{1, _status, %{msg_log_data: ^compressed_log_data} = withdrawal}] =
                 Withdrawal.transaction_statuses(transaction.hash)

        refute Map.has_key?(withdrawal, :msg_log_compressed_data)
      end
    end

    # Inserts a withdrawal and its `MessagePassed` log, which keeps `first_topic`
    # only in `first_topic_id` as all logs imported by v12+ do.
    defp insert_withdrawal_with_message_passed_log(nonce, log_data_attrs) do
      transaction = :transaction |> insert() |> with_block()

      Repo.insert!(%Withdrawal{
        msg_nonce: Decimal.new(nonce),
        hash: transaction_hash(),
        l2_transaction_hash: transaction.hash,
        l2_block_number: transaction.block_number
      })

      insert(
        :log,
        [
          transaction: transaction,
          block: transaction.block,
          block_number: transaction.block_number,
          first_topic: nil,
          first_topic_id: LogFirstTopic.find_or_create(@message_passed_event).id,
          second_topic: "0x" <> String.pad_leading(Integer.to_string(nonce, 16), 64, "0")
        ] ++ log_data_attrs
      )

      transaction
    end
  end
end
