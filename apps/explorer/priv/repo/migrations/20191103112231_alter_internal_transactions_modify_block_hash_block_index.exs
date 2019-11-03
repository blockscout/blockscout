defmodule Explorer.Repo.Migrations.AlterInternalTransactionsModifyBlockHashBlockIndex do
  use Ecto.Migration

  def change do
    alter table(:internal_transactions) do
      modify(:block_hash, references(:blocks, column: :hash, type: :bytea), null: false)
      modify(:block_index, :integer, null: false)
    end
  end
end
