defmodule Explorer.Repo.Migrations.TransactionsBlockNumberBlockHashIndex do
  use Ecto.Migration

  def change do
    create(
      index(
        :transactions,
        ~w(block_number block_hash)a
      )
    )
  end
end
