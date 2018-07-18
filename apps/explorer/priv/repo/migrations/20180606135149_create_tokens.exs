defmodule Explorer.Repo.Migrations.CreateTokens do
  use Ecto.Migration

  def change do
    create table(:tokens) do
      add(:name, :string)
      add(:symbol, :string)
      add(:total_supply, :decimal)
      add(:decimals, :smallint)

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
