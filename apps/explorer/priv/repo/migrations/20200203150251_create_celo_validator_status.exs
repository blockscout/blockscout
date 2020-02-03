defmodule Explorer.Repo.Migrations.CreateCeloAccount do
  use Ecto.Migration

  def change do
    create table(:celo_validator_status) do
      add(:signer_address_hash, :bytea, null: false)
      add(:last_elected, :integer, null: false)
      add(:last_online, :integer, null: false)

      timestamps(null: false, type: :utc_datetime_usec)
    end

    create(index(:celo_validator_status, [:signer_address_hash], unique: true))

  end
end
