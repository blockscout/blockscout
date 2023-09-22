defmodule Explorer.Repo.Suave.Migrations.AddSuaveTransactionFields do
  use Ecto.Migration

  def change do
    alter table(:transactions) do
      add(:execution_node_hash, references(:addresses, column: :hash, type: :bytea), null: true)
    end
  end
end
