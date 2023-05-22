defmodule Explorer.Repo.Migrations.ExtendTokenNameType do
  use Ecto.Migration

  def change do
    alter table(:tokens) do
      modify(:name, :text, null: true)
    end
  end
end
