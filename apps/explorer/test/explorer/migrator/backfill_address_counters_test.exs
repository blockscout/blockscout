# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Migrator.BackfillAddressCountersTest do
  use Explorer.DataCase, async: false

  import Ecto.Query

  alias Explorer.Chain.Address
  alias Explorer.Chain.Cache.Counters.{AddressCountersConsolidator, Consolidation}
  alias Explorer.Migrator.{BackfillAddressCounters, MigrationStatus}
  alias Explorer.Repo

  setup do
    initial_consolidation_env = Application.get_env(:explorer, Consolidation) || []

    Application.put_env(
      :explorer,
      Consolidation,
      Keyword.merge(initial_consolidation_env, safe_block_lag: 0)
    )

    initial_migrator_env = Application.get_env(:explorer, BackfillAddressCounters) || []

    Application.put_env(
      :explorer,
      BackfillAddressCounters,
      Keyword.merge(initial_migrator_env, batch_size: 2, concurrency: 2, timeout: 0)
    )

    on_exit(fn ->
      Application.put_env(:explorer, Consolidation, initial_consolidation_env)
      Application.put_env(:explorer, BackfillAddressCounters, initial_migrator_env)
    end)

    :ok
  end

  test "backfills counters for addresses that were never consolidated" do
    insert(:block, number: 0)
    block = insert(:block, number: 100)

    active_address = insert(:address, transactions_count: 999, token_transfers_count: 999, gas_used: 999)
    transaction = :transaction |> insert(from_address: active_address) |> with_block(block)

    dormant_address = insert(:address)

    already_consolidated_address =
      insert(:address, transactions_count: 42, token_transfers_count: 42, gas_used: 42, counters_updated_at: 77)

    assert MigrationStatus.get_status("backfill_address_counters") == nil

    BackfillAddressCounters.start_link([])

    wait_for_results(fn ->
      Repo.one!(
        from(ms in MigrationStatus,
          where: ms.migration_name == ^"backfill_address_counters" and ms.status == "completed"
        )
      )
    end)

    safe_block = AddressCountersConsolidator.safe_block()

    active_reloaded = Repo.get(Address, active_address.hash)
    assert active_reloaded.transactions_count == 1
    assert active_reloaded.token_transfers_count == 0
    assert active_reloaded.gas_used == Decimal.to_integer(transaction.gas_used)
    assert active_reloaded.counters_updated_at == safe_block

    dormant_reloaded = Repo.get(Address, dormant_address.hash)
    assert dormant_reloaded.transactions_count == 0
    assert dormant_reloaded.token_transfers_count == 0
    assert dormant_reloaded.gas_used == 0
    assert dormant_reloaded.counters_updated_at == safe_block

    # addresses already consolidated are left untouched
    consolidated_reloaded = Repo.get(Address, already_consolidated_address.hash)
    assert consolidated_reloaded.transactions_count == 42
    assert consolidated_reloaded.counters_updated_at == 77

    # nothing is left to process
    assert Repo.one(from(a in Address, where: is_nil(a.counters_updated_at), select: count())) == 0
  end

  test "resumes from the cursor stored in the migration meta" do
    insert(:block, number: 0)
    insert(:block, number: 100)

    addresses = Enum.map(1..5, fn _ -> insert(:address) end)
    max_hash = addresses |> Enum.map(&to_string(&1.hash)) |> Enum.max()

    BackfillAddressCounters.start_link([])

    wait_for_results(fn ->
      Repo.one!(
        from(ms in MigrationStatus,
          where: ms.migration_name == ^"backfill_address_counters" and ms.status == "completed"
        )
      )
    end)

    %{meta: meta} = MigrationStatus.fetch("backfill_address_counters")

    assert meta["max_processed_hash"] >= max_hash
  end
end
