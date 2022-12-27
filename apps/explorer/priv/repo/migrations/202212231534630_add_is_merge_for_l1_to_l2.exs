defmodule Explorer.Repo.Migrations.AddIsMergeForL1ToL2 do
  use Ecto.Migration

  def change do
    alter table(:l1_to_l2) do
      add(:is_merge, :boolean, null: false, default: false)
    end
  end
end
