defmodule Explorer.Repo.Migrations.CreateTokenUiMultiplierChanges do
  use Ecto.Migration

  def change do
    create table(:token_ui_multiplier_changes, primary_key: false) do
      add(:token_contract_address_hash, :bytea, null: false, primary_key: true)
      add(:block_number, :bigint, null: false, primary_key: true)
      add(:block_hash, :bytea, null: false)
      add(:log_index, :integer, null: false, primary_key: true)
      add(:old_multiplier, :decimal, null: false)
      add(:new_multiplier, :decimal, null: false)
      add(:effective_at, :utc_datetime_usec, null: false)

      timestamps()
    end
  end
end
