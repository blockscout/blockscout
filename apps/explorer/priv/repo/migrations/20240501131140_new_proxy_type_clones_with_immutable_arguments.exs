defmodule Explorer.Repo.Migrations.NewProxyTypeClonesWithImmutableArguments do
  use Ecto.Migration

  def change do
    execute("ALTER TYPE proxy_type ADD VALUE 'clone_with_immutable_arguments' BEFORE 'unknown'")
  end
end
