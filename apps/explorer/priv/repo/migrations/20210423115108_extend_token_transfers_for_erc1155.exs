defmodule Explorer.Repo.Migrations.ExtendTokenTransfersForErc1155 do
  use Ecto.Migration

  def change do
    alter table(:token_transfers) do
      add(:amounts, {:array, :decimal}, null: true)
      add(:token_ids, {:array, :numeric}, precision: 78, scale: 0, null: true)
    end
  end
end
