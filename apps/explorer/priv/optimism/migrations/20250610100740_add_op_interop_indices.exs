defmodule Explorer.Repo.Optimism.Migrations.AddOPInteropIndices do
  use Ecto.Migration

  def change do
    create(index(:op_interop_messages, [:init_transaction_hash, :init_chain_id, :sent_to_multichain, :block_number]))
    create(index(:op_interop_messages, [:relay_transaction_hash, :relay_chain_id, :sent_to_multichain, :block_number]))
  end
end
