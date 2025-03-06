defmodule Explorer.Repo.Migrations.NewProxyTypeResolvedDelegateProxy do
  use Ecto.Migration

  def change do
    execute("ALTER TYPE proxy_type ADD VALUE 'resolved_delegate_proxy' BEFORE 'unknown'")
  end
end
