defmodule Explorer.Repo.Migrations.AddIndexToTokenTransfers do
  use Ecto.Migration
  @disable_ddl_transaction false

  def change do
    create(index("token_transfers", [:token_contract_address_hash, :block_number, :log_index], concurrently: false))
  end
end
