defmodule Explorer.Repo.Migrations.TransactionsBlockNumberBlockHashIndex do
  use Ecto.Migration

  def change do
    create(
      index(
        :public.transactions,
        ~w(block_number block_hash)a,
        concurrently: true
      )
    )
  end
end
