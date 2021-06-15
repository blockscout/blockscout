defmodule Explorer.Repo.Migrations.AdditionalInternalTransactionConstraints do
  @moduledoc """
  Use `priv/repo/migrations/scripts/20181108205650_additional_internal_transaction_constraints.sql` to migrate data and
  validate constraint.

  ```sh
  mix ecto.migrate
  psql -d $DATABASE -a -f priv/repo/migrations/scripts/20181108205650_additional_internal_transaction_constraints.sql
  ```

  NOTE: you may want to consider using `apps/explorer/priv/repo/migrations/scripts/20181108205650_large_additional_internal_transaction_constraints.sql`
  instead if you are dealing with a very large number of transactions/internal-transactions.
  """

  use Ecto.Migration

  def up do
    execute("""
    ALTER TABLE internal_transactions
    ADD CONSTRAINT call_has_call_type
    CHECK (type != 'call' OR call_type IS NOT NULL)
    NOT VALID
    """)

    execute("""
    ALTER TABLE internal_transactions
    ADD CONSTRAINT call_has_input
    CHECK (type != 'call' OR input IS NOT NULL)
    NOT VALID
    """)

    execute("""
    ALTER TABLE internal_transactions
    ADD CONSTRAINT create_has_init
    CHECK (type != 'create' OR init IS NOT NULL)
    NOT VALID
    """)
  end

  def down do
    drop(constraint(:internal_transactions, :call_has_call_type))
    drop(constraint(:internal_transactions, :call_has_input))
    drop(constraint(:internal_transactions, :create_has_init))
  end
end
