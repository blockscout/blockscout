defmodule Explorer.Repo.Migrations.AddVerifiedViaEthBytecodeDb do
  use Ecto.Migration

  def change do
    alter table(:smart_contracts) do
      add(:verified_via_eth_bytecode_db, :boolean, null: true)
    end
  end
end
