defmodule Explorer.Repo.Migrations.InternalTransactionsCompositePrimaryKey do
  use Ecto.Migration

  def up do
    # Remove old id
    alter table(:internal_transactions) do
      remove(:id)
    end

    # Don't use `modify` as it requires restating the whole column description
    execute("ALTER TABLE internal_transactions ADD PRIMARY KEY (transaction_hash, index)")
  end

  def down do
    execute("ALTER TABLE internal_transactions DROP CONSTRAINT internal_transactions_pkey")

    # Add back old id
    alter table(:internal_transactions) do
      add(:id, :bigserial, primary_key: true)
    end
  end
end
