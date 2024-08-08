defmodule Explorer.Repo.Migrations.AddInternalTransactionToAddressHashIndex do
  use Ecto.Migration

  def change do
    create(index(:internal_transactions, :to_address_hash))
  end
end
