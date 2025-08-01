defmodule Explorer.Repo.ZkSync.Migrations.AddContractCodeRefetched do
  use Ecto.Migration

  def change do
    alter table(:addresses) do
      add(:contract_code_refetched, :boolean, default: false)
    end

    execute("""
    ALTER TABLE addresses ALTER COLUMN contract_code_refetched SET DEFAULT true;
    """)
  end
end
