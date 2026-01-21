defmodule Explorer.Repo.Migrations.ResetTokensExtendedSkipMetadata do
  use Ecto.Migration

  def change do
    execute("""
    UPDATE tokens SET skip_metadata = null WHERE skip_metadata IS TRUE AND decimals IS NOT NULL AND name IS NOT NULL AND symbol IS NOT NULL
    """)
  end
end
