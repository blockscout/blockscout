defmodule Explorer.Repo.Celo.Migrations.CreatePendingAccountOperations do
  use Ecto.Migration

  def change do
    create table(:celo_pending_account_operations, primary_key: false) do
      add(
        :address_hash,
        references(
          :addresses,
          column: :hash,
          type: :bytea,
          on_delete: :delete_all
        ),
        primary_key: true
      )

      timestamps()
    end
  end
end
