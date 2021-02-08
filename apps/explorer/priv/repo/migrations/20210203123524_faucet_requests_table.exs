defmodule Explorer.Repo.Migrations.FaucetRequestsTable do
  use Ecto.Migration

  def change do
    create table(:faucet_requests, primary_key: false) do
      add(:receiver_hash, references(:addresses, column: :hash, type: :bytea), null: false)

      timestamps()
    end

    create(index(:faucet_requests, :receiver_hash))
    create(index(:faucet_requests, :inserted_at))
  end
end
