defmodule Explorer.Repo.Migrations.SetContractEventsCompatibility do
  use Ecto.Migration

  def change do
    execute(
      "ALTER TABLE celo_contract_events ADD COLUMN bq_rep_id bigserial",
      "ALTER TABLE celo_contract_events DROP COLUMN bq_rep_id"
    )
  end
end
