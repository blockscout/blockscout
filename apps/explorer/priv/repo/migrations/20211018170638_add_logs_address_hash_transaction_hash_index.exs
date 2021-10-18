defmodule Explorer.Repo.Migrations.AddLogsAddressHashTransactionHashIndex do
  use Ecto.Migration

  def change do
    create(
      index(
        :logs,
        ~w(address_hash transaction_hash)a,
        concurrently: true
      )
    )
  end
end
