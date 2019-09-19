defmodule Explorer.Repo.Migrations.AddBlockHashToAllEntities do
  use Ecto.Migration

  def change do
    alter table(:address_coin_balances) do
      add(:block_hash, :bytea)
    end

    create(index(:address_coin_balances, [:block_hash]))

    alter table(:address_current_token_balances) do
      add(:block_hash, :bytea)
    end

    create(index(:address_current_token_balances, [:block_hash]))

    alter table(:address_token_balances) do
      add(:block_hash, :bytea)
    end

    create(index(:address_token_balances, [:block_hash]))

    alter table(:internal_transactions) do
      add(:block_hash, :bytea)
    end

    create(index(:internal_transactions, [:block_hash]))

    alter table(:logs) do
      add(:block_hash, :bytea)
    end

    create(index(:logs, [:block_hash]))

    alter table(:token_transfers) do
      add(:block_hash, :bytea)
    end

    create(index(:token_transfers, [:block_hash]))
  end
end
