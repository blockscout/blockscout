defmodule Explorer.Repo.Filecoin.Migrations.ReplaceFilecoinAddressesIndexes do
  use Ecto.Migration

  def change do
    drop_if_exists(unique_index(:addresses, [:filecoin_robust]))
    drop_if_exists(unique_index(:addresses, [:filecoin_id]))

    create(index(:addresses, [:filecoin_robust]))
    create(index(:addresses, [:filecoin_id]))
  end
end
