defmodule Explorer.Repo.Migrations.NewProxyTypeEip7702 do
  use Ecto.Migration

  def change do
    execute("ALTER TYPE proxy_type ADD VALUE 'eip7702' BEFORE 'unknown'")
  end
end
