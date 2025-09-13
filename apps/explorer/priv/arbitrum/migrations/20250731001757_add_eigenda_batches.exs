defmodule Explorer.Repo.Arbitrum.Migrations.AddEigendaBatches do
  use Ecto.Migration

  def change do
    execute("ALTER TYPE arbitrum_da_containers_types ADD VALUE 'in_eigenda'")
  end
end
