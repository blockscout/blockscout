defmodule Explorer.Repo.Filecoin.Migrations.CreatePendingAddressOperations do
  use Ecto.Migration

  def change do
    create table(:filecoin_pending_address_operations, primary_key: false) do
      add(
        :address_hash,
        references(
          :addresses,
          column: :hash,
          type: :bytea,
          on_delete: :delete_all
        ),
        null: false,
        primary_key: true
      )

      add(:http_status_code, :smallint)

      timestamps()
    end
  end
end
