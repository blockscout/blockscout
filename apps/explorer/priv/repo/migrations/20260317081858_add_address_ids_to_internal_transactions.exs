defmodule Explorer.Repo.Migrations.AddAddressIdsToInternalTransactions do
  use Ecto.Migration

  def change do
    alter table(:internal_transactions) do
      add(:from_address_id, :bigint)
      add(:to_address_id, :bigint)
      add(:created_contract_address_id, :bigint)
    end

    drop_if_exists(
      constraint(
        :internal_transactions,
        :selfdestruct_has_from_and_to_address,
        check:
          "type != 'selfdestruct' OR (from_address_hash IS NOT NULL AND gas IS NULL AND to_address_hash IS NOT NULL)",
        validate: false
      )
    )

    create(
      constraint(
        :internal_transactions,
        :selfdestruct_has_from_and_to_address,
        check: "type != 'selfdestruct' OR (from_address_id IS NOT NULL AND gas IS NULL AND to_address_id IS NOT NULL)",
        validate: false
      )
    )

    drop_if_exists(
      constraint(
        :internal_transactions,
        :create_has_error_id_or_result,
        check: """
        type != 'create' OR
        (gas IS NOT NULL AND
         ((error_id IS NULL AND created_contract_address_hash IS NOT NULL AND created_contract_code IS NOT NULL AND gas_used IS NOT NULL) OR
          (error_id IS NOT NULL AND created_contract_address_hash IS NULL AND created_contract_code IS NULL AND gas_used IS NULL)))
        """,
        validate: false
      )
    )

    create(
      constraint(
        :internal_transactions,
        :create_has_error_id_or_result,
        check: """
        type != 'create' OR
        (gas IS NOT NULL AND
         ((error_id IS NULL AND created_contract_address_id IS NOT NULL AND created_contract_code IS NOT NULL AND gas_used IS NOT NULL) OR
          (error_id IS NOT NULL AND created_contract_address_id IS NULL AND created_contract_code IS NULL AND gas_used IS NULL)))
        """,
        validate: false
      )
    )
  end
end
