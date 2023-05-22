defmodule Explorer.Repo.Migrations.DropRequiredOutputConstraint do
  use Ecto.Migration

  def change do
    drop(
      constraint(
        :internal_transactions,
        :call_has_error_or_result,
        check: """
        type != 'call' OR
        (gas IS NOT NULL AND
         ((error IS NULL AND gas_used IS NOT NULL and output IS NOT NULL) OR
          (error IS NOT NULL AND gas_used IS NULL and output is NULL)))
        """
      )
    )

    create(
      constraint(
        :internal_transactions,
        :call_has_error_or_result,
        check: """
        type != 'call' OR
        (gas IS NOT NULL AND
         ((error IS NULL AND gas_used IS NOT NULL AND output IS NOT NULL) OR
          (error IS NOT NULL AND output is NULL)))
        """
      )
    )
  end
end
