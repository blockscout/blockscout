defmodule Explorer.Repo.Arbitrum.Migrations.ExtendTransactionAndBlockTables do
  use Ecto.Migration

  def change do
    alter table(:blocks) do
      add(:send_count, :integer)
      add(:send_root, :bytea)
      add(:l1_block_number, :integer)
    end

    alter table(:transactions) do
      add(:gas_used_for_l1, :numeric, precision: 100)
    end
  end
end
