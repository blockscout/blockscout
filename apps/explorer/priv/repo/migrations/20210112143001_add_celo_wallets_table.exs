defmodule Explorer.Repo.Migrations.AddCeloWalletsTable do
  use Ecto.Migration

  def change do
    create table(:celo_wallets) do
      add(:wallet_address_hash, references(:addresses, column: :hash, type: :bytea), null: false)
      add(:account_address_hash, references(:addresses, column: :hash, type: :bytea), null: false)
      add(:block_number, :integer, null: false)
      timestamps(null: false, type: :utc_datetime_usec)
    end

    create_if_not_exists(index(:celo_wallets, [:wallet_address_hash, :account_address_hash], unique: true))
    create_if_not_exists(index(:celo_wallets, [:account_address_hash]))
  end
end
