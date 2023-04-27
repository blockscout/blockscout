defmodule Explorer.Repo.Migrations.AddOpIndexes do
  use Ecto.Migration

  def change do
    create(index(:op_output_roots, [:l1_block_number]))
    create(index(:op_withdrawal_events, [:l1_block_number]))
  end
end
