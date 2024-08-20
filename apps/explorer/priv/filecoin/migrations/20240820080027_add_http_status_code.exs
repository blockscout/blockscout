defmodule Explorer.Repo.Filecoin.Migrations.AddHttpStatusCode do
  use Ecto.Migration

  def change do
    execute(
      """
      ALTER TABLE filecoin_pending_address_operations
      ADD COLUMN http_status_code SMALLINT;
      """,
      """
      ALTER TABLE filecoin_pending_address_operations
      DROP COLUMN http_status_code;
      """
    )
  end
end
