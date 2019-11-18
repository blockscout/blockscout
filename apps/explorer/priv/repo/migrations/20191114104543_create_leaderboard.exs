defmodule Explorer.Repo.Migrations.CreateLeaderboard do
  use Ecto.Migration

  def change do
    create table(:competitors) do
      add(:address, :bytea, null: false)
      add(:multiplier, :real, null: false)
      add(:old_gold, :numeric, precision: 100)
      add(:old_usd, :numeric, precision: 100)
    end

    create(index(:competitors, [:address], unique: true))

    create table(:claims) do
      add(:address, :bytea, null: false)
      add(:claimed_address, :bytea, null: false)
    end

    create(index(:claims, [:address, :claimed_address], unique: true))

    create table(:exchange_rates) do
      add(:token, :bytea, null: false)
      add(:rate, :real, null: false)
    end

    create(index(:exchange_rates, [:token], unique: true))

    execute("CREATE type json_type AS (address char(40), multiplier real)")
    execute("CREATE type json_assoc AS (address char(40), claimed_address char(40))")
    execute("CREATE type json_rate AS (token bytea, rate real)")
  end
end
