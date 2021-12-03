defmodule Explorer.Repo.Migrations.AddContractVerificationStatusTable do
  use Ecto.Migration
  
  def change do
    create table("contract_verification_status") do
      add(:uid, :string, size: 64)
      add(:status, :int2, null: false)
      add(:address_hash, :bytea, null: false)

      timestamps()
    end
  end
end
