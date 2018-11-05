defmodule Explorer.Repo.Migrations.LogsCompositePrimaryKey do
  use Ecto.Migration

  def up do
    # Remove old id
    alter table(:logs) do
      remove(:id)
    end

    # Don't use `modify` as it requires restating the whole column description
    execute("ALTER TABLE logs ADD PRIMARY KEY (transaction_hash, index)")
  end

  def down do
    execute("ALTER TABLE logs DROP CONSTRAINT logs_pkey")

    # Add back old id
    alter table(:logs) do
      add(:id, :bigserial, primary_key: true)
    end
  end
end
