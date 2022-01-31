defmodule Explorer.Repo.Migrations.AddCheckForBytecodeActuality do
  use Ecto.Migration

  def change do
    alter table(:smart_contracts) do
      add(:is_changed_bytecode, :boolean, default: false)
      # subtracting 1 day to perform first check
      add(:bytecode_checked_at, :"timestamp without time zone",
        default: fragment("(NOW() AT TIME ZONE 'utc') - INTERVAL '1 DAY'")
      )
    end
  end
end
