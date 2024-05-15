defmodule Explorer.Repo.Migrations.AddProxyTypeColumn do
  use Ecto.Migration

  def change do
    execute(
      "CREATE TYPE proxy_type AS ENUM ('eip1167', 'eip1967', 'eip1822', 'eip930', 'master_copy', 'basic_implementation', 'basic_get_implementation', 'comptroller', 'unknown')",
      "DROP TYPE proxy_type"
    )

    alter table(:proxy_implementations) do
      add(:proxy_type, :proxy_type, null: true)
    end

    create(index(:proxy_implementations, [:proxy_type]))
  end
end
