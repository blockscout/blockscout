defmodule Explorer.Repo.Scroll.Migrations.RenameFields do
  use Ecto.Migration

  def change do
    rename(table(:scroll_l1_fee_params), :tx_index, to: :transaction_index)
  end
end
