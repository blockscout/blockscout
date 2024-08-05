defmodule Explorer.Repo.Arbitrum.Migrations.ExtendTransactionAndBlockTables do
  use Ecto.Migration

  def change do
    alter table(:blocks) do
      add_if_not_exists(:send_count, :integer)
      add_if_not_exists(:send_root, :bytea)
      add_if_not_exists(:l1_block_number, :integer)
    end

    alter table(:transactions) do
      add_if_not_exists(:gas_used_for_l1, :numeric, precision: 100)
    end
  end
end
