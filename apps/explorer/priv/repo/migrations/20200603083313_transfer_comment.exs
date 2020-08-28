defmodule Explorer.Repo.Migrations.AddTransferComment do
  use Ecto.Migration

  def change do
    alter table(:token_transfers) do
      add(:comment, :string, size: 1024)
    end
  end
end
