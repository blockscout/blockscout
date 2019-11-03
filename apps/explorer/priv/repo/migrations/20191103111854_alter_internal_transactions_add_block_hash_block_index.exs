defmodule Explorer.Repo.Migrations.AlterInternalTransactionsAddBlockHashBlockIndex do
  use Ecto.Migration

  def change do
  	alter table(:internal_transactions) do
      # add(:block_hash, :bytea)
      add(:block_index, :integer)
    end
  end
end
