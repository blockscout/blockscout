defmodule Explorer.Repo.BridgedTokens.Migrations.AddBridgedTokens do
  use Ecto.Migration

  def change do
    alter table(:tokens) do
      add(:bridged, :boolean, null: true)
    end

    create table(:bridged_tokens, primary_key: false) do
      add(:foreign_chain_id, :numeric, null: false)
      add(:foreign_token_contract_address_hash, :bytea, null: false)
      add(:exchange_rate, :decimal)
      add(:custom_metadata, :string, null: true)
      add(:lp_token, :boolean, null: true)
      add(:custom_cap, :decimal, null: true)
      add(:type, :string, null: true)

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
