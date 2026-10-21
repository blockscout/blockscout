# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Migrator.BackfillTokenCountersTest do
  use Explorer.DataCase, async: false

  import Ecto.Query

  alias Explorer.Chain.Cache.Counters.Consolidation
  alias Explorer.Chain.Token
  alias Explorer.Migrator.{BackfillTokenCounters, MigrationStatus}
  alias Explorer.Repo

  setup do
    initial_consolidation_env = Application.get_env(:explorer, Consolidation) || []

    Application.put_env(
      :explorer,
      Consolidation,
      Keyword.merge(initial_consolidation_env, safe_block_lag: 0)
    )

    initial_migrator_env = Application.get_env(:explorer, BackfillTokenCounters) || []

    Application.put_env(
      :explorer,
      BackfillTokenCounters,
      Keyword.merge(initial_migrator_env, batch_size: 2, concurrency: 2, timeout: 0)
    )

    on_exit(fn ->
      Application.put_env(:explorer, Consolidation, initial_consolidation_env)
      Application.put_env(:explorer, BackfillTokenCounters, initial_migrator_env)
    end)

    :ok
  end

  test "backfills counters for tokens that were never consolidated" do
    insert(:block, number: 0)
    block = insert(:block, number: 100)

    # legacy values written at unknown heights get recalculated
    active_token = insert(:token, transfer_count: 999, holder_count: 999)

    transaction = :transaction |> insert() |> with_block(block)

    insert(:token_transfer,
      transaction: transaction,
      block: block,
      block_number: block.number,
      token_contract_address: active_token.contract_address
    )

    insert(:address_current_token_balance, token_contract_address_hash: active_token.contract_address_hash, value: 10)

    dormant_token = insert(:token, transfer_count: nil, holder_count: nil)

    already_consolidated_token = insert(:token, transfer_count: 42, holder_count: 42, counters_updated_at: 77)

    assert MigrationStatus.get_status("backfill_token_counters") == nil

    BackfillTokenCounters.start_link([])

    wait_for_results(fn ->
      Repo.one!(
        from(ms in MigrationStatus,
          where: ms.migration_name == ^"backfill_token_counters" and ms.status == "completed"
        )
      )
    end)

    safe_block = Consolidation.safe_block()

    active_reloaded = Repo.get_by(Token, contract_address_hash: active_token.contract_address_hash)
    assert active_reloaded.transfer_count == 1
    assert active_reloaded.holder_count == 1
    assert active_reloaded.counters_updated_at == safe_block

    dormant_reloaded = Repo.get_by(Token, contract_address_hash: dormant_token.contract_address_hash)
    assert dormant_reloaded.transfer_count == 0
    assert dormant_reloaded.holder_count == 0
    assert dormant_reloaded.counters_updated_at == safe_block

    # tokens already consolidated are left untouched
    consolidated_reloaded = Repo.get_by(Token, contract_address_hash: already_consolidated_token.contract_address_hash)
    assert consolidated_reloaded.transfer_count == 42
    assert consolidated_reloaded.holder_count == 42
    assert consolidated_reloaded.counters_updated_at == 77

    # nothing is left to process
    assert Repo.one(from(token in Token, where: is_nil(token.counters_updated_at), select: count())) == 0
  end

  test "resumes from the cursor stored in the migration meta" do
    insert(:block, number: 0)
    insert(:block, number: 100)

    tokens = Enum.map(1..5, fn _ -> insert(:token) end)
    max_hash = tokens |> Enum.map(&to_string(&1.contract_address_hash)) |> Enum.max()

    BackfillTokenCounters.start_link([])

    wait_for_results(fn ->
      Repo.one!(
        from(ms in MigrationStatus,
          where: ms.migration_name == ^"backfill_token_counters" and ms.status == "completed"
        )
      )
    end)

    %{meta: meta} = MigrationStatus.fetch("backfill_token_counters")

    assert meta["max_processed_hash"] >= max_hash
  end
end
