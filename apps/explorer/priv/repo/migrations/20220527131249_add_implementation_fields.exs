defmodule Explorer.Repo.Migrations.AddImplementationFields do
  use Ecto.Migration

  def change do
    alter table(:smart_contracts) do
      add(:implementation_address_hash, :bytea, null: true)
      add(:implementation_fetched_at, :"timestamp without time zone", null: true)
    end
  end
end
