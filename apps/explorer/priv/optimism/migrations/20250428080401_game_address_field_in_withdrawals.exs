defmodule Explorer.Repo.Optimism.Migrations.GameAddressFieldInWithdrawals do
  use Ecto.Migration

  def change do
    alter table(:op_withdrawal_events) do
      add(:game_address, :bytea, null: true)
    end

    create(index(:op_dispute_games, :address))
  end
end
