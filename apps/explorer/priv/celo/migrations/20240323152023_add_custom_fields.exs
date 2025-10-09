defmodule Explorer.Repo.Celo.Migrations.AddCustomFields do
  use Ecto.Migration

  def change do
    alter table(:transactions) do
      add(:gateway_fee, :numeric, precision: 100, null: true)
      add(:gas_token_contract_address_hash, :bytea, null: true)
      add(:gas_fee_recipient_address_hash, :bytea, null: true)
    end
  end
end
