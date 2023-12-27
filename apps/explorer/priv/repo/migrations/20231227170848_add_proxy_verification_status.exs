defmodule Explorer.Repo.Migrations.AddProxyVerificationStatus do
  use Ecto.Migration

  def change do
    create table("proxy_verification_status", primary_key: false) do
      add(:uid, :string, size: 64, primary_key: true)
      add(:status, :int2, null: false)
      add(:address_hash, :bytea, null: false)

      timestamps()
    end
  end
end
