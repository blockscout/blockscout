defmodule Explorer.Repo.Migrations.CreateLogsAddressHashTransactionHashIndex do
  use Ecto.Migration

  def change do
    create(
      index(
        :logs,
        ~w(address_hash transaction_hash)a
      )
    )
  end
end
