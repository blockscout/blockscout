defmodule Explorer.Repo.Migrations.AddCallTypeEnumToInternalTransactions do
  use Ecto.Migration

  def change do
    execute(
      "CREATE TYPE internal_transactions_call_type AS ENUM ('call', 'callcode', 'delegatecall', 'staticcall', 'invalid')",
      "DROP TYPE internal_transactions_call_type"
    )

    alter table(:internal_transactions) do
      add(:call_type_enum, :internal_transactions_call_type, null: true)
    end

    create(
      constraint(:internal_transactions, :call_has_call_type_enum,
        check: "type != 'call' OR call_type IS NOT NULL OR call_type_enum IS NOT NULL",
        validate: false
      )
    )

    drop(constraint(:internal_transactions, :call_has_call_type, check: "type != 'call' OR call_type IS NOT NULL"),
      validate: false
    )
  end
end
