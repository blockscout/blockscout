defmodule Explorer.Repo.Migrations.RemoveRedundantIndexes do
  use Ecto.Migration

  def change do
    drop_if_exists(unique_index(:account_custom_abis, [:id]))
    drop_if_exists(unique_index(:account_api_keys, [:value]))
  end
end
