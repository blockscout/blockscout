defmodule Explorer.Repo.Migrations.AddErc7760ToProxyType do
  use Ecto.Migration

  def change do
    execute("ALTER TYPE proxy_type ADD VALUE 'erc7760' BEFORE 'unknown'")
  end
end
