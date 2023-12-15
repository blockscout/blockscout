defmodule Explorer.Repo.Migrations.DropTokenTransfersTokenIdColumn do
  use Ecto.Migration

  def change do
    drop(index(:token_transfers, [:token_id]))
    drop(index(:token_transfers, [:token_contract_address_hash, "token_id DESC", "block_number DESC"]))
    execute("ALTER TABLE token_transfers DROP COLUMN token_id")
  end
end
