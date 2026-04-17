defmodule Explorer.Repo.ShrunkInternalTransactions.Migrations.DropCallHasErrorIdOrResultConstraint do
  use Ecto.Migration

  def change do
    drop_if_exists(
      constraint(
        :internal_transactions,
        :call_has_error_id_or_result,
        check: """
        type != 'call' OR
        (gas IS NOT NULL AND
         ((error_id IS NULL AND gas_used IS NOT NULL AND output IS NOT NULL) OR
          (error_id IS NOT NULL AND output is NULL)))
        """,
        validate: false
      )
    )
  end
end
