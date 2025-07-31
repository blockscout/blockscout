defmodule Explorer.Repo.Migrations.ResetTokensSkipMetadata do
  use Ecto.Migration

  def change do
    execute("""
    UPDATE tokens SET skip_metadata = null WHERE skip_metadata IS TRUE AND decimals IS NULL AND name IS NULL AND symbol IS NULL
    """)
  end
end
