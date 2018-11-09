defmodule Explorer.Repo.Migrations.UpdateTokensTableDecimalsFromBigintToNumeric do
  use Ecto.Migration

  def up do
    alter table("tokens") do
      modify(:decimals, :decimal)
    end
  end

  def down do
    execute("""
    ALTER TABLE tokens
    ALTER COLUMN decimals TYPE bigint
    USING CASE WHEN decimals > 9223372036854775807 THEN NULL ELSE decimals END;
    """)
  end
end
