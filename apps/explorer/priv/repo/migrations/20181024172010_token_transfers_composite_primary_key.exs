defmodule Explorer.Repo.Migrations.TokenTransfersCompositePrimaryKey do
  use Ecto.Migration

  def up do
    # Remove old id
    alter table(:token_transfers) do
      remove(:id)
    end

    # Don't use `modify` as it requires restating the whole column description
    execute("ALTER TABLE token_transfers ADD PRIMARY KEY (transaction_hash, log_index)")
  end

  def down do
    execute("ALTER TABLE token_transfers DROP CONSTRAINT token_transfers_pkey")

    # Add back old id
    alter table(:token_transfers) do
      add(:id, :bigserial, primary_key: true)
    end
  end
end
