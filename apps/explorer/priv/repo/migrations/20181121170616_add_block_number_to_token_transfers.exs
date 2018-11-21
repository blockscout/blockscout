defmodule Explorer.Repo.Migrations.AddBlockNumberToTokenTransfers do
  use Ecto.Migration

  def change do
    alter table(:token_transfers) do
      add(:block_number, :integer)
    end
  end
end
