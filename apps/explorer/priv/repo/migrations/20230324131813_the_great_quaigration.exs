defmodule Explorer.Repo.Migrations.Quaigrate do
  use Ecto.Migration

  def change do
    alter table(:blocks) do
      add :base_fee_per_gas_full, {:array, :numeric}
      add :ext_rollup_root_full, {:array, :bytea}
      add :ext_transactions_root_full, {:array, :bytea}
      add :gas_limit_full, {:array, :numeric}
      add :gas_used_full, {:array, :numeric}
      add :logs_bloom_full, {:array, :bytea}
      add :manifest_hash_full, {:array, :bytea}
      add :miner_full, {:array, :bytea}
      add :number_full, {:array, :bigint}
      add :parent_hash_full, {:array, :bytea}
      add :receipts_root_full, {:array, :bytea}
      add :sha3_uncles_full, {:array, :bytea}
      add :state_root_full, {:array, :bytea}
      add :transactions_root_full, {:array, :bytea}
      add :sub_manifest, {:array, :bytea}
      add :ext_transactions, {:array, :bytea}
      add :location, :string
      add :is_prime_coincident, :boolean
      add :is_region_coincident, :boolean
      add :total_entropy, :numeric
      add :parent_entropy, :numeric
      add :parent_delta_s, :numeric
      add :parent_entropy_full, {:array, :numeric}
      add :parent_delta_s_full, {:array, :numeric}
      remove :total_difficulty
    end
  end
end
