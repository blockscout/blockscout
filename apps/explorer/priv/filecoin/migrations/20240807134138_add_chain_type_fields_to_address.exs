defmodule Explorer.Repo.Filecoin.Migrations.AddChainTypeFieldsToAddress do
  use Ecto.Migration

  def change do
    alter table(:addresses) do
      add(:filecoin_id, :bytea)
      add(:filecoin_robust, :bytea)
    end

    execute(
      "ALTER TABLE addresses ADD COLUMN filecoin_actor_type SMALLINT;",
      "ALTER TABLE addresses DROP COLUMN filecoin_actor_type;"
    )
  end
end
