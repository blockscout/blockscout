defmodule Explorer.Repo.Migrations.AddUrlToCeloAccount do
  use Ecto.Migration

  def change do
    alter table(:celo_account) do
      add(:web_url, :string, size: 2048)
      add(:web_url_verified, :boolean)
      add(:web_url_timestamp, :utc_datetime_usec)
    end
  end
end
