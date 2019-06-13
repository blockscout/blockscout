defmodule Explorer.Repo.Migrations.AddDecompiledAndVerifiedFlagToAddresses do
  use Ecto.Migration

  def change do
    execute(
      """
      ALTER TABLE addresses
      ADD COLUMN IF NOT EXISTS decompiled BOOLEAN,
      ADD COLUMN IF NOT EXISTS verified BOOLEAN;
      """,
      """
      ALTER TABLE addresses
      DROP COLUMN IF EXISTS decompiled,
      DROP COLUMN IF EXISTS verified;
      """
    )
  end
end
