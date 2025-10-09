defmodule Explorer.Repo.Migrations.SmartContractsAddIsBlueprintFlag do
  use Ecto.Migration

  def change do
    alter table(:smart_contracts) do
      add(:is_blueprint, :boolean, null: true)
    end
  end
end
