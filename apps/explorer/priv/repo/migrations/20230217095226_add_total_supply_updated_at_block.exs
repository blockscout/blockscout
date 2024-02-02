defmodule Explorer.Repo.Migrations.AddTotalSupplyUpdatedAtBlock do
  use Ecto.Migration

  def change do
    alter table(:tokens) do
      add(:total_supply_updated_at_block, :bigint)
    end
  end
end
