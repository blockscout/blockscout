defmodule Explorer.Repo.Migrations.CreateL2Block do
  use Ecto.Migration

  def change do
    create table(:l2_block) do
      add :chain, :string, default: "mantle"
      add :l1_block, :integer, default: 0
      add :l2_block, :integer, default: 0
      add :active, :boolean, default: false, null: false

      timestamps()
    end

  end
end
