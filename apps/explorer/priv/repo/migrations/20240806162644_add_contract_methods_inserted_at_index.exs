defmodule Explorer.Repo.Migrations.AddContractMethodsInsertedAtIndex do
  use Ecto.Migration

  def change do
    create(index(:contract_methods, [:inserted_at]))
  end
end
