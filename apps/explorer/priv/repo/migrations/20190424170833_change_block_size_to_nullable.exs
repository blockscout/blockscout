defmodule Explorer.Repo.Migrations.ChangeBlockSizeToNullable do
  use Ecto.Migration

  def up do
    alter table(:blocks) do
      modify(:size, :integer, null: true)
    end
  end

  def down do
    alter table(:blocks) do
      modify(:size, :integer, null: false)
    end
  end
end
