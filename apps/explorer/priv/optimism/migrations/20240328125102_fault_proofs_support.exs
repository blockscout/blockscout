defmodule Explorer.Repo.Optimism.Migrations.FaultProofsSupport do
  use Ecto.Migration

  def change do
    alter table(:op_withdrawal_events) do
      add(:game_index, :integer, null: true)
    end

    create table(:op_dispute_games, primary_key: false) do
      add(:index, :integer, null: false, primary_key: true)
      add(:game_type, :smallint, null: false)
      add(:address, :bytea, null: false)
      add(:extra_data, :bytea, null: true, default: nil)
      add(:created_at, :"timestamp without time zone", null: false)
      add(:resolved_at, :"timestamp without time zone", null: true, default: nil)
      add(:status, :smallint, null: true, default: nil)

      timestamps(null: false, type: :utc_datetime_usec)
    end

    create(index(:op_dispute_games, :game_type))
  end
end
