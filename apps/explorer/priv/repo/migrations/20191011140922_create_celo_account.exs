defmodule Explorer.Repo.Migrations.CreateCeloAccount do
    use Ecto.Migration
  
    def change do
        create table(:celo_account) do
            add(:address, :bytea, null: false)
            add(:account_type, :string)
            add(:gold, :numeric, precision: 100)
            add(:usd, :numeric, precision: 100)
            add(:locked_gold, :numeric, precision: 100)
            add(:rewards, :numeric, precision: 100)
            add(:notice_period, :integer)

            timestamps(null: false, type: :utc_datetime_usec)
        end

        create(index(:celo_account, [:address], unique: true))
    end
end

