defmodule Explorer.Repo.Migrations.MoveAddressKeysToTransactions do
  use Ecto.Migration

  def change do
    alter table(:transactions) do
      add :to_address_id, references(:addresses)
      add :from_address_id, references(:addresses)
    end
  end


end
