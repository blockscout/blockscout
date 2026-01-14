defmodule Explorer.Repo.Migrations.ReRunSanitizeIncorrectNftMigration do
  use Ecto.Migration

  def change do
    execute(
      "UPDATE migrations_status SET status = 'started', meta = '{\"step\": \"delete_erc_1155\"}' WHERE migration_name = 'sanitize_incorrect_nft'"
    )
  end
end
