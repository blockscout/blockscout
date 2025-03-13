defmodule Explorer.Repo.Optimism.Migrations.ReindexBatches do
  use Ecto.Migration

  def change do
    drop_if_exists(index(:op_transaction_batches, [:frame_sequence_id]))
    create_if_not_exists(unique_index(:op_transaction_batches, [:frame_sequence_id, :l2_block_number]))
  end
end
