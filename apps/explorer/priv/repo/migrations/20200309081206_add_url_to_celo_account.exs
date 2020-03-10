defmodule Explorer.Repo.Migrations.AddUrlToCeloAccount do
  use Ecto.Migration

  def change do
    alter table(:celo_account) do
      add(:domain, :string, size: 2048)
      add(:domain_verified, :boolean)
      add(:domain_timestamp, :utc_datetime_usec)
    end
  end
end
