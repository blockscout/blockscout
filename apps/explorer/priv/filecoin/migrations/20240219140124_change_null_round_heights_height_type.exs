defmodule Explorer.Repo.Filecoin.Migrations.ChangeNullRoundHeightsHeightType do
  use Ecto.Migration

  def change do
    alter table(:null_round_heights) do
      modify(:height, :bigint)
    end
  end
end
