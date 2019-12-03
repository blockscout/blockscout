defmodule Explorer.Repo.Migrations.AddFirstTraceFieldsToTransaction do
  use Ecto.Migration

  def change do
    alter table(:transactions) do
      add(:first_trace_gas_used, :numeric, precision: 100, null: true)
      add(:first_trace_output, :bytea, null: true)
    end
  end
end
