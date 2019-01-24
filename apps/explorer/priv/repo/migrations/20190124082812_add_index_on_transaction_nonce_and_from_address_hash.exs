defmodule Explorer.Repo.Migrations.AddIndexOnTransactionNonceAndFromAddressHash do
  use Ecto.Migration

  alias Ecto.Adapters.SQL
  alias Explorer.Repo

  # 30 minutes
  @timeout 60_000 * 30

  def change do
    create(index(:transactions, [:nonce, :from_address_hash, :block_hash]))
    create(index(:transactions, [:block_hash, :error]))
  end
end
