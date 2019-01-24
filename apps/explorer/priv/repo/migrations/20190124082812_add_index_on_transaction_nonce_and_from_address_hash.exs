defmodule Explorer.Repo.Migrations.AddIndexOnTransactionNonceAndFromAddressHash do
  use Ecto.Migration

  alias Ecto.Adapters.SQL
  alias Explorer.Repo

  # 30 minutes
  @timeout 60_000 * 30

  def change do
    create(index(:transactions, [:nonce, :from_address_hash, :block_hash]))
    # for replaced/dropeed transactions
    create(index(:transactions, [:block_hash, :error]))

    query = "UPDATE transactions SET error = 'dropped/replaced', status = 0 FROM transactions t1
    INNER JOIN transactions t2
    ON t1.from_address_hash = t2.from_address_hash AND t1.nonce = t2.nonce
    WHERE t1.block_hash IS NULL AND t2.block_hash IS NOT NULL"

    SQL.query!(
      Repo,
      query,
      [],
      timeout: @timeout
    )
  end
end
