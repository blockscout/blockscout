defmodule Explorer.Repo.Migrations.SmartContractsAddCertifiedFlag do
  use Ecto.Migration
  @disable_ddl_transaction true
  @disable_migration_lock true

  def change do
    alter table("smart_contracts") do
      add(:certified, :boolean, null: true)
    end

    create_if_not_exists(index(:smart_contracts, [:certified]))
  end
end
