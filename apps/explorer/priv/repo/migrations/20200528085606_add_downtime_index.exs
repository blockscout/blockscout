defmodule Explorer.Repo.Migrations.AddDowntimeIndex do
  use Ecto.Migration

  def change do
    create(index(:celo_validator_history, [:address, "block_number desc", :online]))
  end
end
