defmodule Explorer.Repo.Migrations.CreateTokens do
  use Ecto.Migration

  def change do
    create table(:tokens, primary_key: false) do
      # Name, symbol, total supply, and decimals may not always be available from executing a token contract
      # Allow for nulls for those fields
      add(:name, :string, null: true)
      add(:symbol, :string, null: true)
      add(:total_supply, :decimal, null: true)
      add(:decimals, :smallint, null: true)
      add(:type, :string, null: false)
      add(:cataloged, :boolean, default: false)

      add(
        :contract_address_hash,
        references(:addresses, column: :hash, on_delete: :delete_all, type: :bytea),
        null: false
      )

      timestamps()
    end

    create(unique_index(:tokens, :contract_address_hash))
  end
end
