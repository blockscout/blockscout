defmodule Explorer.Repo.Migrations.AddContractVerificationStatusTable do
  use Ecto.Migration
  
  def change do
    create table("contract_verification_status", primary_key: false) do
      add(:uid, :string, size: 64, primary_key: true)
      add(:status, :int2, null: false)
      add(:address_hash, :bytea, null: false)

      timestamps()
    end
  end
end
