defmodule Explorer.Repo.Migrations.IndexTransactionAddressIds do
  use Ecto.Migration

  def change do
    create index(:transactions, :to_address_id)
    create index(:transactions, :from_address_id)
  end
end
