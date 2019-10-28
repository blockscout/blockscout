defmodule Explorer.Repo.Migrations.AddIndexOnTokenTransferTokenId do
  use Ecto.Migration

  def change do
    create_if_not_exists(index(:token_transfers, [:token_id]))
  end
end
