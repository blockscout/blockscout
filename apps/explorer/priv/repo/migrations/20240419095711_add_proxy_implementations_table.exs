defmodule Explorer.Repo.Migrations.AddProxyImplementationsTable do
  use Ecto.Migration

  def change do
    create table(:proxy_implementations) do
      add(:proxy_address_hash, :bytea, null: false, primary_key: true)
      add(:address_hash, :bytea, null: false, primary_key: true)
      add(:name, :string, null: true)

      timestamps()
    end
  end
end
