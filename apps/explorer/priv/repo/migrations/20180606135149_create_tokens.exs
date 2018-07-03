defmodule Explorer.Repo.Migrations.CreateTokens do
  use Ecto.Migration

  def change do
    create table(:tokens) do
      add(:name, :string, null: false)
      add(:symbol, :string, null: false)
      add(:total_supply, :integer, null: false)
      add(:decimals, :smallint, null: false)

      add(
        :owner_address_hash,
        references(:addresses, column: :hash, on_delete: :delete_all, type: :bytea),
        null: false
      )

      add(
        :contract_address_hash,
        references(:addresses, column: :hash, on_delete: :delete_all, type: :bytea),
        null: false
      )
    end

    create(index(:tokens, :owner_address_hash))
    create(unique_index(:tokens, :contract_address_hash))
  end
end
