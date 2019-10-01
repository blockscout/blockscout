defmodule Explorer.Repo.Migrations.AddGasFeeRecipientAndGasCurrencyToTransactions do
  @moduledoc """
  Use `` to migrate data.
  ```sh
  mix ecto.migrate
  psql -d $DATABASE -a -f priv/repo/migrations/scripts/
  ```
  """

  use Ecto.Migration

  def up do
    # Add nonce
    alter table("transactions") do
      add(:gas_currency, references(:addresses, column: :hash, on_delete: :delete_all, type: :bytea), null: false)
      add(:gas_fee_recipient, references(:addresses, column: :hash, on_delete: :delete_all, type: :bytea), null: false)
    end
  end

  def down do
    alter table("transactions") do
      remove(:gas_currency)
      remove(:gas_fee_recipient)
    end
  end
end

