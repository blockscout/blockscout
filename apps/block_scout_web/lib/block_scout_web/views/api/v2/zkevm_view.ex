defmodule BlockScoutWeb.API.V2.ZkevmView do
  use BlockScoutWeb, :view

  @doc """
    Function to render GET requests to `/api/v2/zkevm/batches/:batch_number` endpoint.
  """
  @spec render(binary(), map()) :: map() | non_neg_integer()
  def render("zkevm_batch.json", %{batch: batch}) do
    sequence_tx_hash =
      if Map.has_key?(batch, :sequence_transaction) and not is_nil(batch.sequence_transaction) do
        batch.sequence_transaction.hash
      end

    verify_tx_hash =
      if Map.has_key?(batch, :verify_transaction) and not is_nil(batch.verify_transaction) do
        batch.verify_transaction.hash
      end

    l2_transactions =
      if Map.has_key?(batch, :l2_transactions) do
        Enum.map(batch.l2_transactions, fn tx -> tx.hash end)
      end

    %{
      "number" => batch.number,
      "status" => batch_status(batch),
      "timestamp" => batch.timestamp,
      "transactions" => l2_transactions,
      "global_exit_root" => batch.global_exit_root,
      "acc_input_hash" => batch.acc_input_hash,
      "sequence_tx_hash" => sequence_tx_hash,
      "verify_tx_hash" => verify_tx_hash,
      "state_root" => batch.state_root
    }
  end

  @doc """
    Function to render GET requests to `/api/v2/zkevm/batches` endpoint.
  """
  def render("zkevm_batches.json", %{
        batches: batches,
        next_page_params: next_page_params
      }) do
    %{
      items: render_zkevm_batches(batches),
      next_page_params: next_page_params
    }
  end

  @doc """
    Function to render GET requests to `/api/v2/main-page/zkevm/batches/confirmed` endpoint.
  """
  def render("zkevm_batches.json", %{batches: batches}) do
    %{items: render_zkevm_batches(batches)}
  end

  @doc """
    Function to render GET requests to `/api/v2/zkevm/batches/count` endpoint.
  """
  def render("zkevm_batches_count.json", %{count: count}) do
    count
  end

  @doc """
    Function to render GET requests to `/api/v2/main-page/zkevm/batches/latest-number` endpoint.
  """
  def render("zkevm_batch_latest_number.json", %{number: number}) do
    number
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

  defp render_zkevm_batches(batches) do
    Enum.map(batches, fn batch ->
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
        "tx_count" => batch.l2_transactions_count,
        "sequence_tx_hash" => sequence_tx_hash,
        "verify_tx_hash" => verify_tx_hash
      }
    end)
  end
end
