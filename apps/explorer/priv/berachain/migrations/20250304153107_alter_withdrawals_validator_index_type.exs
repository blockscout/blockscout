defmodule Explorer.Repo.Berachain.Migrations.AlterWithdrawalsValidatorIndexType do
  use Ecto.Migration

  def change do
    alter table("withdrawals") do
      modify(:validator_index, :numeric, precision: 20)
    end
  end
end
