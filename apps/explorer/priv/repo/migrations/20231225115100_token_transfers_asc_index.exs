defmodule Explorer.Repo.Migrations.TokenTransfersAscIndex do
  use Ecto.Migration

  def change do
    create(index(:token_transfers, ["block_number ASC", "log_index ASC"]))
  end
end
