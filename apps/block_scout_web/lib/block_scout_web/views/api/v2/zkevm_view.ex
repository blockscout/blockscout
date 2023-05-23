defmodule BlockScoutWeb.API.V2.ZkevmView do
  use BlockScoutWeb, :view

  def render("zkevm_batch.json", %{batch: batch}) do
    sequence_tx_hash =
      if not is_nil(batch.sequence_transaction) do
        batch.sequence_transaction.hash
      end

    verify_tx_hash =
      if not is_nil(batch.verify_transaction) do
        batch.verify_transaction.hash
      end

    %{
      "number" => batch.number,
      "status" => batch_status(batch),
      "timestamp" => batch.timestamp,
      "transactions" => Enum.map(batch.l2_transactions, fn tx -> tx.hash end),
      "global_exit_root" => batch.global_exit_root,
      "acc_input_hash" => batch.acc_input_hash,
      "sequence_tx_hash" => sequence_tx_hash,
      "verify_tx_hash" => verify_tx_hash,
      "state_root" => batch.state_root
    }
  end

  defp batch_status(batch) do
    sequence_id = Map.get(batch, :sequence_id)
    verify_id = Map.get(batch, :verify_id)

    cond do
      is_nil(sequence_id) && is_nil(verify_id) -> "Unfinalized"
      !is_nil(sequence_id) && is_nil(verify_id) -> "L1 Sequence Confirmed"
      !is_nil(verify_id) -> "Finalized"
    end
  end
end
