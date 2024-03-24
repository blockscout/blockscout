defmodule Explorer.Repo.Celo.Migrations.AddCustomFields do
  use Ecto.Migration

  def change do
    alter table(:transactions) do
      add(:gateway_fee, :numeric, precision: 100, null: true)
      add(:gas_currency_hash, :bytea, null: true)
      add(:gas_fee_recipient_hash, :bytea, null: true)
      add(:eth_compatible, :boolean, null: true)
    end
  end
end
