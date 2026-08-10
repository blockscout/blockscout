# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Chain.Address.CountersTest do
  use Explorer.DataCase

  alias Explorer.Chain.Address.Counters

  describe "check_if_logs_at_address/2" do
    test "detects logs stored with `address_id` and with the legacy `address_hash` while the optimized fields migration is in progress" do
      set_fill_logs_optimized_fields_migration_started()

      address_with_migrated_log = insert(:address)
      address_with_legacy_log = insert(:address)
      address_without_logs = insert(:address)

      transaction =
        :transaction
        |> insert()
        |> with_block()

      log_params = [block: transaction.block, block_number: transaction.block_number, transaction: transaction]

      # already migrated log, matched by `address_id`
      insert(:log, log_params ++ [index: 1, address: address_with_migrated_log, address_hash: nil])
      # not yet migrated log, matched by the legacy `address_hash`
      insert(:log, log_params ++ [index: 2, address: address_with_legacy_log, address_mapping: nil])

      assert Counters.check_if_logs_at_address(address_with_migrated_log.hash)
      assert Counters.check_if_logs_at_address(address_with_legacy_log.hash)
      refute Counters.check_if_logs_at_address(address_without_logs.hash)
    end
  end

  describe "address_limited_counters/2" do
    test "counts logs matched by `address_id` and by the legacy `address_hash` while the optimized fields migration is in progress" do
      set_fill_logs_optimized_fields_migration_started()

      address = insert(:address)

      transaction =
        :transaction
        |> insert(to_address: address)
        |> with_block()

      log_params = [
        block: transaction.block,
        block_number: transaction.block_number,
        transaction: transaction,
        address: address
      ]

      # already migrated logs, matched by `address_id`
      insert(:log, log_params ++ [index: 1, address_hash: nil])
      insert(:log, log_params ++ [index: 2, address_hash: nil])
      # not yet migrated log, matched by the legacy `address_hash`
      insert(:log, log_params ++ [index: 3, address_mapping: nil])
      # re-imported log with both fields filled, counted once
      insert(:log, log_params ++ [index: 4])
      # log of another address
      insert(:log, log_params ++ [index: 5, address: insert(:address), address_mapping: nil])

      assert %{logs: 4} = Counters.address_limited_counters(address.hash, [])
    end
  end
end
