defmodule Explorer.Repo.Optimism.Migrations.OPOperatorFee do
  use Ecto.Migration

  def up do
    alter table(:transactions) do
      add(:operator_fee_scalar, :decimal, null: true, default: nil)
      add(:operator_fee_constant, :decimal, null: true, default: nil)
    end

    execute("""
      CREATE INDEX transactions_operator_fee_constant_index ON transactions(operator_fee_constant) WHERE operator_fee_constant IS NULL;
    """)
  end

  def down do
    execute("""
      DROP INDEX transactions_operator_fee_constant_index;
    """)

    alter table(:transactions) do
      remove(:operator_fee_constant)
      remove(:operator_fee_scalar)
    end
  end
end
