defmodule Explorer.Repo.Migrations.Quaigrate do
  use Ecto.Migration

  def change do
    alter table(:blocks) do
      add :manifest_hash_full, {:array, :bytea}
      add :number_full, {:array, :bigint}
      add :parent_entropy_full, {:array, :numeric}
      add :parent_delta_s_full, {:array, :numeric}
      add :parent_hash_full, {:array, :bytea}
      add :sub_manifest, {:array, :bytea}
      add :ext_rollup_root, :bytea
      add :transactions_root, :bytea
      add :ext_transactions_root, :bytea
      add :location, :string
      add :is_prime_coincident, :boolean
      add :is_region_coincident, :boolean
      add :total_entropy, :numeric
      add :parent_entropy, :numeric
      add :parent_delta_s, :numeric
      remove :total_difficulty
    end
  end
end
