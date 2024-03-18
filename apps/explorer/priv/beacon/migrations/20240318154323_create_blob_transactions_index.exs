defmodule Explorer.Repo.Beacon.Migrations.AddTransactionsRecentBlobTransactionsIndex do
  use Ecto.Migration

  def change do
    create_if_not_exists(
      index(:transactions, ["block_number DESC, index DESC"],
        name: :transactions_recent_blob_transactions_index,
        where: "type = 3",
        concurrently: true
      )
    )
  end
end
