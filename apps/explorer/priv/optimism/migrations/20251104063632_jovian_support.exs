defmodule Explorer.Repo.Optimism.Migrations.JovianSupport do
  use Ecto.Migration

  def change do
    alter table(:op_eip1559_config_updates) do
      add(:min_base_fee, :bigint, null: true)
    end
  end
end
