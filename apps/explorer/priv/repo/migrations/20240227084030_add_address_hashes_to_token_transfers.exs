defmodule Explorer.Repo.Migrations.AddAddressHashesToTokenTransfers do
  use Ecto.Migration

  def change do
    alter table(:token_transfers) do
      add(:address_hashes, {:array, :bytea}, null: true)
    end

    execute("""
    CREATE INDEX CONCURRENTLY on token_transfers USING GIN ("address_hashes") WHERE block_consensus;
    """)
  end
end
