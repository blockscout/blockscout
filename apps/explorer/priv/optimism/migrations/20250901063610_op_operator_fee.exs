defmodule Explorer.Repo.Optimism.Migrations.OPOperatorFee do
  use Ecto.Migration

  def change do
    alter table(:transactions) do
      add(:operator_fee_scalar, :decimal, null: true, default: nil)
      add(:operator_fee_constant, :decimal, null: true, default: nil)
    end
  end
end
