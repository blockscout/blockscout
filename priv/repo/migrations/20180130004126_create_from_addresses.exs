defmodule Explorer.Repo.Migrations.CreateFromAddresses do
  use Ecto.Migration

  def change do
    create table(:from_addresses, primary_key: false) do
      add :transaction_id, references(:transactions), null: false, primary_key: true
      add :address_id, references(:addresses), null: false
      timestamps null: false
    end

    create index(:from_addresses, :transaction_id, unique: true)
    create index(:from_addresses, :address_id)
  end
end
