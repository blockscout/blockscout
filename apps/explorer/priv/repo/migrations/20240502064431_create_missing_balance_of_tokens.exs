defmodule Explorer.Repo.Migrations.CreateMissingBalanceOfTokens do
  use Ecto.Migration

  def change do
    create table(:missing_balance_of_tokens, primary_key: false) do
      add(:token_contract_address_hash, :bytea, primary_key: true)
      add(:block_number, :bigint)

      timestamps()
    end
  end
end
