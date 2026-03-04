defmodule Explorer.Repo.Optimism.Migrations.OPDropOperatorFeeIndex do
  use Ecto.Migration

  def change do
    execute(
      "UPDATE migrations_status SET status = 'completed', updated_at = NOW() WHERE migration_name = 'heavy_indexes_create_transactions_operator_fee_constant_index' AND status = 'started'"
    )
  end
end
