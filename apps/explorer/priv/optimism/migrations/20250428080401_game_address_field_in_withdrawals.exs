defmodule Explorer.Repo.Optimism.Migrations.GameAddressFieldInWithdrawals do
  use Ecto.Migration

  def change do
    alter table(:op_withdrawal_events) do
      add(:game_address_hash, :bytea, null: true)
    end

    rename(table(:op_dispute_games), :address, to: :address_hash)
    create(index(:op_dispute_games, :address_hash))
  end
end
