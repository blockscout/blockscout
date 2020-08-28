defmodule Explorer.Repo.Migrations.AddExtraData do
  use Ecto.Migration

  def change do
    alter table(:blocks) do
      add(:extra_data, :bytea)
      add(:round, :integer)
    end
  end
end
