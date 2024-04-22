defmodule Explorer.Repo.Migrations.DropTokenTransfersTokenIdsIndex do
  use Ecto.Migration

  def change do
    drop_if_exists(index(:token_transfers, [:token_ids], name: :token_transfers_token_ids_index))
  end
end
