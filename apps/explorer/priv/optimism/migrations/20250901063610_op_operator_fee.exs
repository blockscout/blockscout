defmodule Explorer.Repo.Optimism.Migrations.OPOperatorFee do
  use Ecto.Migration

  def up do
    alter table(:transactions) do
      add(:operator_fee_scalar, :decimal, null: true, default: nil)
      add(:operator_fee_constant, :decimal, null: true, default: nil)
    end
  end

  def down do
    alter table(:transactions) do
      remove(:operator_fee_constant)
      remove(:operator_fee_scalar)
    end
  end
end
