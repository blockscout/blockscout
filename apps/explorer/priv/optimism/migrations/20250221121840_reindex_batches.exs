defmodule Explorer.Repo.Optimism.Migrations.ReindexBatches do
  use Ecto.Migration

  def change do
    execute("DROP INDEX IF EXISTS \"op_transaction_batches_frame_sequence_id_l2_block_number_idx\";")
    drop_if_exists(index(:op_transaction_batches, [:frame_sequence_id]))
    create(unique_index(:op_transaction_batches, [:frame_sequence_id, :l2_block_number]))
  end
end
