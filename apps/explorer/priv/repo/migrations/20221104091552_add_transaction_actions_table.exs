defmodule Explorer.Repo.Migrations.AddTransactionActionsTable do
  use Ecto.Migration

  def change do
    execute(
      "CREATE TYPE transaction_actions_protocol AS ENUM ('uniswap_v3', 'opensea_v1.1', 'wrapping', 'approval', 'zkbob')",
      "DROP TYPE transaction_actions_protocol"
    )

    execute(
      "CREATE TYPE transaction_actions_type AS ENUM ('mint_nft', 'mint', 'burn', 'collect', 'swap', 'sale', 'cancel', 'transfer', 'wrap', 'unwrap', 'approve', 'revoke', 'withdraw', 'deposit')",
      "DROP TYPE transaction_actions_type"
    )

    create table(:transaction_actions) do
      add(:hash, references(:transactions, column: :hash, on_delete: :delete_all, on_update: :update_all, type: :bytea),
        null: false
      )

      add(:protocol, :transaction_actions_protocol, null: false)
      add(:data, :map, default: %{}, null: false)
      add(:type, :transaction_actions_type, null: false)

      timestamps(null: false, type: :utc_datetime_usec)
    end

    create(index(:transaction_actions, :hash))
    create(index(:transaction_actions, [:protocol, :type]))
  end
end
