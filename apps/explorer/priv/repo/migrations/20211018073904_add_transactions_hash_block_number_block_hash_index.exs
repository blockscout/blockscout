defmodule Explorer.Repo.Migrations.AddTransactionsHashBlockNumberBlockHashIndex do
  use Ecto.Migration

  def change do
    create(
      index(
        :transactions,
        ~w(hash block_number block_hash)a,
        concurrently: true
      )
    )
  end
end
