defmodule Explorer.Repo.Filecoin.Migrations.CreateNullRoundHeights do
  use Ecto.Migration

  def change do
    create table(:null_round_heights, primary_key: false) do
      add(:height, :integer, primary_key: true)
    end
  end
end
