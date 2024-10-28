defmodule Explorer.Repo.ZkSync.Migrations.AddContractCodeRecollected do
  use Ecto.Migration

  def change do
    alter table(:addresses) do
      add(:contract_code_recollected, :boolean, default: false)
    end

    execute("""
    ALTER TABLE addresses ALTER COLUMN contract_code_recollected SET DEFAULT true;
    """)
  end
end
