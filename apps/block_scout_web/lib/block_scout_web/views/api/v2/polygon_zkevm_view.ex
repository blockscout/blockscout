defmodule BlockScoutWeb.API.V2.PolygonZkevmView do
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

  @doc """
    Function to render GET requests to `/api/v2/zkevm/deposits` and `/api/v2/zkevm/withdrawals` endpoints.
  """
  def render("polygon_zkevm_bridge_items.json", %{
        items: items,
        next_page_params: next_page_params
      }) do
    env = Application.get_all_env(:indexer)[Indexer.Fetcher.PolygonZkevm.BridgeL1]

    %{
      items:
        Enum.map(items, fn item ->
          l1_token = if is_nil(Map.get(item, :l1_token)), do: %{}, else: Map.get(item, :l1_token)
          l2_token = if is_nil(Map.get(item, :l2_token)), do: %{}, else: Map.get(item, :l2_token)

          decimals =
            cond do
              not is_nil(Map.get(l1_token, :decimals)) -> Map.get(l1_token, :decimals)
              not is_nil(Map.get(l2_token, :decimals)) -> Map.get(l2_token, :decimals)
              true -> env[:native_decimals]
            end

          symbol =
            cond do
              not is_nil(Map.get(l1_token, :symbol)) -> Map.get(l1_token, :symbol)
              not is_nil(Map.get(l2_token, :symbol)) -> Map.get(l2_token, :symbol)
              true -> env[:native_symbol]
            end

          %{
            "block_number" => item.block_number,
            "index" => item.index,
            "l1_transaction_hash" => item.l1_transaction_hash,
            "timestamp" => item.block_timestamp,
            "l2_transaction_hash" => item.l2_transaction_hash,
            "value" => fractional(Decimal.new(item.amount), Decimal.new(decimals)),
            "symbol" => symbol
          }
        end),
      next_page_params: next_page_params
    }
  end

  @doc """
    Function to render GET requests to `/api/v2/zkevm/deposits/count` and `/api/v2/zkevm/withdrawals/count` endpoints.
  """
  def render("polygon_zkevm_bridge_items_count.json", %{count: count}) do
    count
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

  defp fractional(%Decimal{} = amount, %Decimal{} = decimals) do
    amount.sign
    |> Decimal.new(amount.coef, amount.exp - Decimal.to_integer(decimals))
    |> Decimal.normalize()
    |> Decimal.to_string(:normal)
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
