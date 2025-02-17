defmodule Explorer.Repo.Filecoin.Migrations.AddChainTypeFieldsToAddress do
  use Ecto.Migration

  def change do
    alter table(:addresses) do
      add(:filecoin_id, :bytea)
      add(:filecoin_robust, :bytea)
      add(:filecoin_actor_type, :smallint)
    end
  end
end
