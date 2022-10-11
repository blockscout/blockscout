defmodule Explorer.Repo.Migrations.CreateCeloAccountsEpochsTable do
  use Ecto.Migration

  def change do
    create table(:celo_accounts_epochs, primary_key: false) do
      add(:account_hash, references(:addresses, column: :hash, type: :bytea), null: false, primary_key: true)

      add(:block_hash, references(:blocks, column: :hash, type: :bytea, on_delete: :delete_all),
        null: false,
        primary_key: true
      )

      add(:locked_gold, :numeric, precision: 100, null: false)
      add(:activated_gold, :numeric, precision: 100, null: false)

      timestamps(null: false, type: :utc_datetime_usec)
    end
  end
end
