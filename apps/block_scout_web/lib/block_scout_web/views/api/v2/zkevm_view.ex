defmodule BlockScoutWeb.API.V2.ZkevmView do
  use BlockScoutWeb, :view

  def render("zkevm_batch.json", %{batch: batch}) do
    %{
      "number" => batch.number,
      "status" => batch_status(batch),
      "timestamp" => batch.timestamp
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
