defmodule Explorer.Repo.Berachain.Migrations.AlterWithdrawalsIndexType do
  use Ecto.Migration

  def change do
    alter table("withdrawals") do
      modify(:index, :numeric, precision: 20)
    end
  end
end
