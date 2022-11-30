defmodule Explorer.Repo.Migrations.CreateTokenTransferTokenIdMigratorProgress do
  use Ecto.Migration

  def change do
    create table(:token_transfer_token_id_migrator_progress) do
      add(:last_processed_block_number, :integer)

      timestamps()
    end
  end
end
