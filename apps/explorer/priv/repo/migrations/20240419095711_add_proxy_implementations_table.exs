defmodule Explorer.Repo.Migrations.AddProxyImplementationsTable do
  use Ecto.Migration

  def change do
    create table(:proxy_implementations, primary_key: false) do
      add(:proxy_address_hash, :bytea, null: false, primary_key: true)
      add(:address_hashes, {:array, :bytea}, null: false)
      add(:names, {:array, :string}, null: false)

      timestamps()
    end
  end
end
