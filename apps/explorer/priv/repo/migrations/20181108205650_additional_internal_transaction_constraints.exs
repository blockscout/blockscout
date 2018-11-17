defmodule Explorer.Repo.Migrations.AdditionalInternalTransactionConstraints do
  use Ecto.Migration

  def up do
    create(constraint(:internal_transactions, :call_has_call_type, check: "type != 'call' OR call_type IS NOT NULL"))
    create(constraint(:internal_transactions, :call_has_input, check: "type != 'call' OR input IS NOT NULL"))
    create(constraint(:internal_transactions, :create_has_init, check: "type != 'create' OR init IS NOT NULL"))
  end

  def down do
    drop(constraint(:internal_transactions, :call_has_call_type))
    drop(constraint(:internal_transactions, :call_has_input))
    drop(constraint(:internal_transactions, :create_has_init))
  end
end
