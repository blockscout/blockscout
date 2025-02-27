defmodule Explorer.Repo.Migrations.UpdateLastFetchedCountersKeys do
  use Ecto.Migration

  def change do
    execute(
      "UPDATE last_fetched_counters SET counter_type = 'verified_contracts_count', updated_at = NOW() WHERE counter_type = 'verified_contracts_counter'"
    )

    execute(
      "UPDATE last_fetched_counters SET counter_type = 'new_verified_contracts_count', updated_at = NOW() WHERE counter_type = 'new_verified_contracts_counter'"
    )

    execute(
      "UPDATE last_fetched_counters SET counter_type = 'contracts_count', updated_at = NOW() WHERE counter_type = 'contracts_counter'"
    )

    execute(
      "UPDATE last_fetched_counters SET counter_type = 'new_contracts_count', updated_at = NOW() WHERE counter_type = 'new_contracts_counter'"
    )

    execute(
      "UPDATE last_fetched_counters SET counter_type = 'blocks_count', updated_at = NOW() WHERE counter_type = 'block_count'"
    )

    execute(
      "UPDATE last_fetched_counters SET counter_type = 'addresses_coin_balance_sum_minus_burnt', updated_at = NOW() WHERE counter_type = 'sum_coin_total_supply_minus_burnt'"
    )
  end
end
