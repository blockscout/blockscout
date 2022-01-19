defmodule Explorer.Repo.Migrations.SmartContractsAddIsVyperFlag do
  use Ecto.Migration

  def change do
    alter table(:smart_contracts) do
      add(:is_vyper_contract, :boolean, null: true)
    end
  end
end
