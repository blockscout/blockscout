defmodule Explorer.Repo.Migrations.CreateTransactionErrors do
  use Ecto.Migration

  def change do
    create table(:transaction_errors, primary_key: false) do
      add(:id, :smallserial, primary_key: true)
      add(:message, :string, null: false)

      timestamps(updated_at: false)
    end

    create(unique_index(:transaction_errors, [:message]))

    alter table(:internal_transactions) do
      add(:error_id, :smallint)
    end

    drop_if_exists(
      constraint(
        :internal_transactions,
        :create_has_error_or_result,
        check: """
        type != 'create' OR
        (gas IS NOT NULL AND
         ((error IS NULL AND created_contract_address_hash IS NOT NULL AND created_contract_code IS NOT NULL AND gas_used IS NOT NULL) OR
          (error IS NOT NULL AND created_contract_address_hash IS NULL AND created_contract_code IS NULL AND gas_used IS NULL)))
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
         ((error_id IS NULL AND created_contract_address_hash IS NOT NULL AND created_contract_code IS NOT NULL AND gas_used IS NOT NULL) OR
          (error_id IS NOT NULL AND created_contract_address_hash IS NULL AND created_contract_code IS NULL AND gas_used IS NULL)))
        """,
        validate: false
      )
    )

    drop_if_exists(
      constraint(
        :internal_transactions,
        :call_has_error_or_result,
        check: """
        type != 'call' OR
        (gas IS NOT NULL AND
         ((error IS NULL AND gas_used IS NOT NULL AND output IS NOT NULL) OR
          (error IS NOT NULL AND output is NULL)))
        """,
        validate: false
      )
    )

    create(
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
