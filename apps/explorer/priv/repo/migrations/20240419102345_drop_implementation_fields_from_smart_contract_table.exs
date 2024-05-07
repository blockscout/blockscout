defmodule Explorer.Repo.Migrations.DropImplementationFieldsFromSmartContractTable do
  use Ecto.Migration

  def change do
    alter table(:smart_contracts) do
      remove(:implementation_address_hash)
      remove(:implementation_fetched_at)
      remove(:implementation_name)
    end
  end
end
