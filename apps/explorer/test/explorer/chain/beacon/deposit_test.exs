# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Chain.Beacon.DepositTest do
  use Explorer.DataCase

  alias Explorer.Chain.Beacon.Deposit
  alias Explorer.Chain.Hash

  @deposit_event_signature "0x649BBC62D0E31342AFEA4E5CD82D4049E7E1EE912FC0889AA790803BE39038C5"

  describe "get_logs_with_deposits/4" do
    test "fetches logs matched by `address_id` and by the legacy `address_hash` while the optimized fields migration is in progress" do
      set_fill_logs_optimized_fields_migration_started()

      deposit_contract_address = insert(:address)
      {:ok, first_topic} = Hash.Full.cast(@deposit_event_signature)

      transaction =
        :transaction
        |> insert(to_address: deposit_contract_address)
        |> with_block()

      log_params = [
        block: transaction.block,
        block_number: transaction.block_number,
        transaction: transaction,
        address: deposit_contract_address,
        first_topic: first_topic
      ]

      # already migrated log, matched by `address_id`
      insert(:log, log_params ++ [index: 1, address_hash: nil])
      # not yet migrated log, matched by the legacy `address_hash`
      insert(:log, log_params ++ [index: 2, address_mapping: nil])
      # re-imported log with both fields filled, returned once
      insert(:log, log_params ++ [index: 3])
      # log of another address
      insert(:log, log_params ++ [index: 4, address: insert(:address), address_mapping: nil])
      # log with another first topic
      insert(:log, log_params ++ [index: 5, first_topic: nil, address_hash: nil])

      logs = Deposit.get_logs_with_deposits(deposit_contract_address.hash, transaction.block_number - 1, 0, 10)

      assert [1, 2, 3] == Enum.map(logs, & &1.index)

      assert Enum.all?(logs, fn log ->
               log.block_number == transaction.block_number and log.transaction_hash == transaction.hash and
                 log.from_address_hash == transaction.from_address_hash and log.first_topic == first_topic
             end)
    end

    test "respects the limit and the paging key while the optimized fields migration is in progress" do
      set_fill_logs_optimized_fields_migration_started()

      deposit_contract_address = insert(:address)
      {:ok, first_topic} = Hash.Full.cast(@deposit_event_signature)

      transaction =
        :transaction
        |> insert(to_address: deposit_contract_address)
        |> with_block()

      log_params = [
        block: transaction.block,
        block_number: transaction.block_number,
        transaction: transaction,
        address: deposit_contract_address,
        first_topic: first_topic
      ]

      insert(:log, log_params ++ [index: 1, address_hash: nil])
      insert(:log, log_params ++ [index: 2, address_mapping: nil])
      insert(:log, log_params ++ [index: 3, address_hash: nil])

      assert [1] ==
               deposit_contract_address.hash
               |> Deposit.get_logs_with_deposits(transaction.block_number - 1, 0, 1)
               |> Enum.map(& &1.index)

      assert [2, 3] ==
               deposit_contract_address.hash
               |> Deposit.get_logs_with_deposits(transaction.block_number, 1, 10)
               |> Enum.map(& &1.index)
    end
  end
end
