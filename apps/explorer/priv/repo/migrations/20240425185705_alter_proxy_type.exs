defmodule Explorer.Repo.Migrations.AlterProxyType do
  use Ecto.Migration

  def change do
    execute("ALTER TYPE proxy_type ADD VALUE 'eip2535' BEFORE 'unknown'")
  end
end
