defmodule BlockScoutWeb.API.V2.ZkSyncView do
  use BlockScoutWeb, :view

  @doc """
    Function to render GET requests to `/api/v2/zksync/batches/:batch_number` endpoint.
  """
  @spec render(binary(), map()) :: map() | non_neg_integer()
  def render("zksync_batch.json", %{batch: batch}) do

    l1_txs = get_associated_l1_txs(batch)

    # l2_transactions =
    #   if Map.has_key?(batch, :l2_transactions) do
    #     Enum.map(batch.l2_transactions, fn tx -> tx.hash end)
    #   end

    %{
      "number" => batch.number,
      "status" => batch_status(l1_txs),
      "timestamp" => batch.timestamp,
      # "transactions" => l2_transactions,
      "root_hash" => batch.root_hash,
      "l1_tx_count" => batch.l1_tx_count,
      "l2_tx_count" => batch.l2_tx_count,
      "l1_gas_price" => batch.l1_gas_price,
      "l2_fair_gas_price" => batch.l2_fair_gas_price,
      "start_block" => batch.start_block,
      "end_block" => batch.end_block,
      "commit_transaction_hash" => get_2map_data(l1_txs, :commit_transaction, :hash),
      "commit_transaction_timestamp" => get_2map_data(l1_txs, :commit_transaction, :ts),
      "prove_transaction_hash" => get_2map_data(l1_txs, :prove_transaction, :hash),
      "prove_transaction_timestamp" => get_2map_data(l1_txs, :prove_transaction, :ts),
      "execute_transaction_hash" => get_2map_data(l1_txs, :execute_transaction, :hash),
      "execute_transaction_timestamp" => get_2map_data(l1_txs, :execute_transaction, :ts)
    }
  end

  @doc """
    Function to render GET requests to `/api/v2/zksync/batches` endpoint.
  """
  def render("zksync_batches.json", %{
        batches: batches,
        next_page_params: next_page_params
      }) do
    %{
      items: render_zksync_batches(batches),
      next_page_params: next_page_params
    }
  end

  @doc """
    Function to render GET requests to `/api/v2/main-page/zksync/batches/confirmed` endpoint.
  """
  def render("zksync_batches.json", %{batches: batches}) do
    %{items: render_zksync_batches(batches)}
  end

  @doc """
    Function to render GET requests to `/api/v2/zksync/batches/count` endpoint.
  """
  def render("zksync_batches_count.json", %{count: count}) do
    count
  end

  @doc """
    Function to render GET requests to `/api/v2/main-page/zksync/batches/latest-number` endpoint.
  """
  def render("zksync_batch_latest_number.json", %{number: number}) do
    number
  end

  defp get_associated_l1_txs(batch) do
    [:commit_transaction, :prove_transaction, :execute_transaction]
    |> Enum.reduce(%{}, fn key, l1_txs ->
      with value <- Map.get(batch, key),
          false <- is_nil(value) do
        Map.put(l1_txs, key, %{hash: value.hash, ts: value.timestamp})
      else
        _ ->
          Map.put(l1_txs, key, nil)
      end
    end)
  end

  defp batch_status(l1_txs) do
    cond do
      not is_nil(l1_txs.execute_transaction) -> "Executed"
      not is_nil(l1_txs.prove_transaction) -> "Validated"
      not is_nil(l1_txs.commit_transaction) -> "Processed"
      true -> "Sealed"
    end
  end

  defp render_zksync_batches(batches) do
    Enum.map(batches, fn batch ->
      l1_txs = get_associated_l1_txs(batch)

      %{
        "number" => batch.number,
        "status" => batch_status(l1_txs),
        "timestamp" => batch.timestamp,
        "tx_count" => batch.l1_tx_count + batch.l2_tx_count,
        "commit_transaction_hash" => get_2map_data(l1_txs, :commit_transaction, :hash),
        "commit_transaction_timestamp" => get_2map_data(l1_txs, :commit_transaction, :ts),
        "prove_transaction_hash" => get_2map_data(l1_txs, :prove_transaction, :hash),
        "prove_transaction_timestamp" => get_2map_data(l1_txs, :prove_transaction, :ts),
        "execute_transaction_hash" => get_2map_data(l1_txs, :execute_transaction, :hash),
        "execute_transaction_timestamp" => get_2map_data(l1_txs, :execute_transaction, :ts)
      }
    end)
  end

  defp get_2map_data(map, key1, key2) do
    with inner_map <- Map.get(map, key1),
         false <- is_nil(inner_map) do
      Map.get(inner_map, key2)
    else
      _ ->
        nil
    end
  end

end
