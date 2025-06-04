defmodule Explorer.Repo.Stability.Migrations.AddValidatorBlocksValidatedCounter do
  use Ecto.Migration

  def change do
    alter table(:validators_stability) do
      add(:blocks_validated, :integer, null: true)
    end

    execute("""
    UPDATE validators_stability v
    SET blocks_validated = COALESCE(
      (SELECT COUNT(*)
       FROM blocks b
       WHERE b.miner_hash = v.address_hash),
      0
    );
    """)

    alter table(:validators_stability) do
      modify(:blocks_validated, :integer, null: false)
    end
  end
end
