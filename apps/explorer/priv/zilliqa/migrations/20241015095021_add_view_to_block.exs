defmodule Explorer.Repo.Zilliqa.Migrations.AddViewToBlock do
  use Ecto.Migration

  def change do
    alter table(:blocks) do
      add(:zilliqa_view, :integer)
    end
  end
end
