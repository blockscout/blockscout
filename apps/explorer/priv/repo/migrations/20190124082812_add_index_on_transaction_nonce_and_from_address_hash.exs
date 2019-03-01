defmodule Explorer.Repo.Migrations.AddIndexOnTransactionNonceAndFromAddressHash do
  use Ecto.Migration

  def change do
    create(index(:transactions, [:nonce, :from_address_hash, :block_hash]))
    create(index(:transactions, [:block_hash, :error]))
  end
end
