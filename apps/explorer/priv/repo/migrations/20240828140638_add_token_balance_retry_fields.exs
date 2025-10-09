defmodule Explorer.Repo.Migrations.AddTokenBalanceRetryFields do
  use Ecto.Migration

  def change do
    alter table(:address_token_balances) do
      add(:refetch_after, :utc_datetime_usec)
      add(:retries_count, :smallint)
    end
  end
end
