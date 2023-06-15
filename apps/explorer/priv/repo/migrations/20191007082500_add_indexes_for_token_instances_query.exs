defmodule Explorer.Repo.Migrations.AddIndexesForTokenInstancesQuery do
  use Ecto.Migration

  def change do
    create_if_not_exists(index(:token_instances, [:token_id]))
    create_if_not_exists(index(:tokens, [:type]))
  end
end
