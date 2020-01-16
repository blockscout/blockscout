defmodule Explorer.Repo.Migrations.AddErrorToTokenInstances do
  use Ecto.Migration

  def change do
    alter table(:token_instances) do
      add(:error, :string)
    end

    create(index(:token_instances, [:error]))
  end
end
