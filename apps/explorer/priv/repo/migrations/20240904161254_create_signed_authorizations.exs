defmodule Explorer.Repo.Migrations.CreateSignedAuthorizations do
  use Ecto.Migration

  def change do
    create table(:signed_authorizations, primary_key: false) do
      add(:transaction_hash, references(:transactions, column: :hash, on_delete: :delete_all, type: :bytea),
        null: false,
        primary_key: true
      )

      add(:index, :integer, null: false, primary_key: true)
      add(:chain_id, :bigint, null: false)
      add(:address, :bytea, null: false)
      add(:nonce, :integer, null: false)
      add(:v, :integer, null: false)
      add(:r, :numeric, precision: 100, null: false)
      add(:s, :numeric, precision: 100, null: false)
      add(:authority, :bytea, null: true)

      timestamps(null: false, type: :utc_datetime_usec)
    end

    create(index(:signed_authorizations, [:authority, :nonce]))
  end
end
