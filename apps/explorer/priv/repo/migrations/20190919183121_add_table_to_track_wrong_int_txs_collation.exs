defmodule Explorer.Repo.Migrations.AddTableToTrackWrongIntTxsCollation do
  @moduledoc """
  IMPORTANT: if the table `blocks_to_invalidate_wrong_int_txs_collation` does not
  exists when this migration is run all the existing block numbers will be refetched.
  """

  use Ecto.Migration

  def up do
    create_if_not_exists table(:blocks_to_invalidate_wrong_int_txs_collation, primary_key: false) do
      add(:block_number, :bigint)
      add(:refetched, :boolean)
    end

    execute("""
    INSERT INTO blocks_to_invalidate_wrong_int_txs_collation
    SELECT DISTINCT number FROM blocks
    WHERE NOT EXISTS (SELECT * FROM blocks_to_invalidate_wrong_int_txs_collation);
    """)
  end

  def down do
    drop_if_exists(table(:blocks_to_invalidate_wrong_int_txs_collation))
  end
end
