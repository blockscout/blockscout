defmodule Explorer.Repo.Migrations.DropIsVyperContractColumn do
  use Ecto.Migration

  def change do
    alter table(:smart_contracts) do
      remove(:is_vyper_contract, :boolean)
    end
  end
end
