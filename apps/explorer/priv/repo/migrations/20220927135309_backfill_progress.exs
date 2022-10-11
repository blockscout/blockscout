defmodule Explorer.Repo.Migrations.BackfillProgress do
  use Ecto.Migration

  def change do
    alter table(:clabs_contract_event_trackings) do
      add(:backfilled_up_to, :jsonb, null: true)
    end
  end
end
