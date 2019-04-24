defmodule Explorer.Repo.Migrations.AddIndexToToAddressHash do
  use Ecto.Migration

  def change do
    create(index(:transactions, [:to_address_hash]))
  end
end
