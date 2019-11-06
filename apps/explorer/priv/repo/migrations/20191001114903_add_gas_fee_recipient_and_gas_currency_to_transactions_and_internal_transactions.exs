defmodule Explorer.Repo.Migrations.AddGasFeeRecipientAndGasCurrencyToTransactions do
  @moduledoc """
  """

  use Ecto.Migration

  def up do
    # Add gas_currency_hash and gas_fee_recipient_hash
    alter table("transactions") do
      add(:gas_currency_hash, :bytea, null: true)
      add(:gas_fee_recipient_hash, :bytea, null: true)
    end

    alter table("internal_transactions") do
      add(:gas_currency_hash, :bytea, null: true)
      add(:gas_fee_recipient_hash, :bytea, null: true)
    end
  end

  def down do
    alter table("transactions") do
      remove(:gas_currency_hash)
      remove(:gas_fee_recipient_hash)
    end

    alter table("internal_transactions") do
      remove(:gas_currency_hash)
      remove(:gas_fee_recipient_hash)
    end
  end
end
