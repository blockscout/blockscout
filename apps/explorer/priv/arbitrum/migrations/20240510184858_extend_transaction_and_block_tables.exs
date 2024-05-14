defmodule Explorer.Repo.Arbitrum.Migrations.ExtendTransactionAndBlockTables do
  use Ecto.Migration

  def change do
    alter table(:blocks) do
      add(:send_count, :integer, null: false)
      add(:send_root, :bytea, null: false)
      add(:l1_block_number, :integer, null: false)
    end

    alter table(:transactions) do
      add(:gas_used_for_l1, :numeric, precision: 100, null: false)
    end
  end
end
