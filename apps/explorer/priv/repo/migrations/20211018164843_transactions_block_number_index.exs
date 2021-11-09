defmodule Explorer.Repo.Migrations.TransactionsBlockNumberIndex do
  use Ecto.Migration

  def change do
    create(
      index(
        :transactions,
        ~w(block_number)a
      )
    )
  end
end
