defmodule Explorer.Repo.Migrations.CreateLogs do
  use Ecto.Migration

  def change do
    create table(:logs) do
      add(:data, :bytea, null: false)
      add(:index, :integer, null: false)

      # Parity supplies it; Geth does not.
      add(:type, :string, null: true)

      add(:first_topic, :string, null: true)
      add(:second_topic, :string, null: true)
      add(:third_topic, :string, null: true)
      add(:fourth_topic, :string, null: true)

      timestamps(null: false, type: :utc_datetime_usec)

      add(:address_hash, references(:addresses, column: :hash, on_delete: :delete_all, type: :bytea), null: true)

      add(
        :transaction_hash,
        references(:transactions, column: :hash, on_delete: :delete_all, type: :bytea),
        null: false
      )
    end

    create(index(:logs, :address_hash))
    create(index(:logs, :transaction_hash))

    create(index(:logs, :index))
    create(index(:logs, :type))
    create(index(:logs, :first_topic))
    create(index(:logs, :second_topic))
    create(index(:logs, :third_topic))
    create(index(:logs, :fourth_topic))
    create(unique_index(:logs, [:transaction_hash, :index]))
  end
end
