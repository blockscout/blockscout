defmodule Explorer.Repo.Migrations.AddTransactionReceivedAt do
  use Ecto.Migration

  def change do
    alter table(:transactions) do
      add_if_not_exists(:received_at_timestamp, :utc_datetime_usec, null: true)
    end
  end
end
