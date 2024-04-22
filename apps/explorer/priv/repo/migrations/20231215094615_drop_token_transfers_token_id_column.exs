defmodule Explorer.Repo.Migrations.DropTokenTransfersTokenIdColumn do
  use Ecto.Migration

  def change do
    drop(index(:token_transfers, [:token_id]))
    drop(index(:token_transfers, [:token_contract_address_hash, "token_id DESC", "block_number DESC"]))

    alter table(:token_transfers) do
      remove(:token_id)
    end
  end
end
