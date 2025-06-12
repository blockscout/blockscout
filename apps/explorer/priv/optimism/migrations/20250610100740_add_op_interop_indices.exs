defmodule Explorer.Repo.Optimism.Migrations.AddOPInteropIndices do
  use Ecto.Migration

  def up do
    create(index(:op_interop_messages, [:init_transaction_hash, :init_chain_id, :sent_to_multichain, :block_number]))
    create(index(:op_interop_messages, [:relay_transaction_hash, :relay_chain_id, :sent_to_multichain, :block_number]))
  end

  def down do
    drop_if_exists(
      index(:op_interop_messages, [:init_transaction_hash, :init_chain_id, :sent_to_multichain, :block_number])
    )

    drop_if_exists(
      index(:op_interop_messages, [:relay_transaction_hash, :relay_chain_id, :sent_to_multichain, :block_number])
    )
  end
end
