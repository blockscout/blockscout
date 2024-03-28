defmodule Explorer.Repo.Optimism.Migrations.FaultProofsSupport do
  use Ecto.Migration

  def change do
    alter table(:op_withdrawal_events) do
      add(:game_index, :integer, null: true)
    end
  end
end
