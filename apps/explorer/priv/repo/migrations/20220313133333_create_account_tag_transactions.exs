defmodule Explorer.Repo.Migrations.CreateAccountTagTransactions do
  use Ecto.Migration

  def change do
    create table(:account_tag_transactions) do
      add(:name, :string)
      add(:identity_id, references(:account_identities, on_delete: :delete_all))

      add(
        :tx_hash,
        references(:transactions, column: :hash, type: :bytea, on_delete: :delete_all)
      )

      timestamps()
    end

    create(index(:account_tag_transactions, [:identity_id]))
    create(index(:account_tag_transactions, [:tx_hash]))
  end
end
