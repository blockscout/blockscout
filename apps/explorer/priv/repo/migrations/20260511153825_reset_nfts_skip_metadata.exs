# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Repo.Migrations.ResetNftsSkipMetadata do
  use Ecto.Migration

  def change do
    execute("""
    UPDATE tokens SET skip_metadata = NULL WHERE skip_metadata = TRUE AND name IS NOT NULL AND symbol IS NOT NULL AND type='ERC-721';
    """)
  end
end
