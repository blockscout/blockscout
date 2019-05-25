defmodule Explorer.Repo.Migrations.AddOldBlockHashForTransactions do
  use Ecto.Migration

  def change do
    alter table(:transactions) do
      # A transient field for deriving old block hash during transaction upserts.
      # Used to force refetch of a block in case a transaction is re-collated
      # in a different block. See: https://github.com/poanetwork/blockscout/issues/1911
      add(:old_block_hash, :bytea, null: true)
    end
  end
end
