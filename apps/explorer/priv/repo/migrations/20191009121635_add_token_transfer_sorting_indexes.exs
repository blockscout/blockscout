defmodule Explorer.Repo.Migrations.AddTokenTransferSortingIndexes do
  use Ecto.Migration

  def change do
    create(
      index(
        :token_transfers,
        ["block_number DESC", "log_index DESC"]
      )
    )
  end
end
