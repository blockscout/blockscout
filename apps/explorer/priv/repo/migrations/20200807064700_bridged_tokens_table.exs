defmodule Explorer.Repo.Migrations.BridgedTokensTable do
  use Ecto.Migration

  def change do
    create table(:bridged_tokens, primary_key: false) do
      add(:foreign_chain_id, :numeric, null: false)
      add(:foreign_token_contract_address_hash, :bytea, null: false)

      add(
        :home_token_contract_address_hash,
        references(:tokens, column: :contract_address_hash, on_delete: :delete_all, type: :bytea),
        null: false
      )

      timestamps()
    end

    create(unique_index(:bridged_tokens, :home_token_contract_address_hash))
  end
end
