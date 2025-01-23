defmodule Explorer.Repo.Filecoin.Migrations.AddFilecoinAddressesIndexes do
  use Ecto.Migration

  def change do
    create(unique_index(:addresses, [:filecoin_robust]))
    create(unique_index(:addresses, [:filecoin_id]))
  end
end
