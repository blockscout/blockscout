defmodule Explorer.Repo.Migrations.CreateInternalTransactionDeleteQueue do
  use Ecto.Migration

  def change do
    create table(:internal_transactions_delete_queue, primary_key: false) do
      add(:block_number, :bigint, primary_key: true)

      timestamps()
    end
  end
end
