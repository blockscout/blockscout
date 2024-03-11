defmodule BlockScoutWeb.API.V2.ZkSyncView do
  use BlockScoutWeb, :view

  alias Explorer.Chain.{Block, Transaction}
  alias Explorer.Chain.ZkSync.TransactionBatch

  @doc """
    Function to render GET requests to `/api/v2/zksync/batches/:batch_number` endpoint.
  """
  @spec render(binary(), map()) :: map() | non_neg_integer()
  def render("zksync_batch.json", %{batch: batch}) do
    l2_transactions =
      if Map.has_key?(batch, :l2_transactions) do
        Enum.map(batch.l2_transactions, fn tx -> tx.hash end)
      end

    %{
      "number" => batch.number,
      "timestamp" => batch.timestamp,
      "root_hash" => batch.root_hash,
      "l1_tx_count" => batch.l1_tx_count,
      "l2_tx_count" => batch.l2_tx_count,
      "l1_gas_price" => batch.l1_gas_price,
      "l2_fair_gas_price" => batch.l2_fair_gas_price,
      "start_block" => batch.start_block,
      "end_block" => batch.end_block,
      "transactions" => l2_transactions
    }
    |> add_l1_txs_info_and_status(batch)
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

  defp render_zksync_batches(batches) do
    Enum.map(batches, fn batch ->
      %{
        "number" => batch.number,
        "timestamp" => batch.timestamp,
        "tx_count" => batch.l1_tx_count + batch.l2_tx_count
      }
      |> add_l1_txs_info_and_status(batch)
    end)
  end

  @doc """
    Extends the json output with a sub-map containing information related
    zksync: batch number and associated L1 transactions and their timestmaps.

    ## Parameters
    - `out_json`: a map defining output json which will be extended
    - `entity`: transaction or block structure containing zksync related data

    ## Returns
    A map extended with data related zksync rollup
  """
  @spec add_zksync_info(map(), %{
          :__struct__ => Explorer.Chain.Block | Explorer.Chain.Transaction,
          :zksync_batch => any(),
          :zksync_commit_transaction => any(),
          :zksync_execute_transaction => any(),
          :zksync_prove_transaction => any(),
          optional(any()) => any()
        }) :: map()
  def add_zksync_info(out_json, entity)

  def add_zksync_info(out_json, %Transaction{} = transaction) do
    do_add_zksync_info(out_json, transaction)
  end

  def add_zksync_info(out_json, %Block{} = block) do
    do_add_zksync_info(out_json, block)
  end

  defp do_add_zksync_info(out_json, zksync_entity) do
    res =
      %{}
      |> do_add_l1_txs_info_and_status(%{
        batch_number: get_batch_number(zksync_entity),
        commit_transaction: zksync_entity.zksync_commit_transaction,
        prove_transaction: zksync_entity.zksync_prove_transaction,
        execute_transaction: zksync_entity.zksync_execute_transaction
      })
      |> Map.put("batch_number", get_batch_number(zksync_entity))

    Map.put(out_json, "zksync", res)
  end

  defp get_batch_number(zksync_entity) do
    case Map.get(zksync_entity, :zksync_batch) do
      nil -> nil
      %Ecto.Association.NotLoaded{} -> nil
      value -> value.number
    end
  end

  defp add_l1_txs_info_and_status(out_json, %TransactionBatch{} = batch) do
    do_add_l1_txs_info_and_status(out_json, batch)
  end

  defp do_add_l1_txs_info_and_status(out_json, zksync_item) do
    l1_txs = get_associated_l1_txs(zksync_item)

    out_json
    |> Map.merge(%{
      "status" => batch_status(zksync_item),
      "commit_transaction_hash" => get_2map_data(l1_txs, :commit_transaction, :hash),
      "commit_transaction_timestamp" => get_2map_data(l1_txs, :commit_transaction, :ts),
      "prove_transaction_hash" => get_2map_data(l1_txs, :prove_transaction, :hash),
      "prove_transaction_timestamp" => get_2map_data(l1_txs, :prove_transaction, :ts),
      "execute_transaction_hash" => get_2map_data(l1_txs, :execute_transaction, :hash),
      "execute_transaction_timestamp" => get_2map_data(l1_txs, :execute_transaction, :ts)
    })
  end

  # Extract transaction hash and timestamp for L1 transactions associated with
  # a zksync rollup entity: batch, transaction or block.
  #
  # ## Parameters
  # - `zksync_item`: A batch, transaction, or block.
  #
  # ## Returns
  # A map containing nesting maps describing corresponding L1 transactions
  defp get_associated_l1_txs(zksync_item) do
    [:commit_transaction, :prove_transaction, :execute_transaction]
    |> Enum.reduce(%{}, fn key, l1_txs ->
      case Map.get(zksync_item, key) do
        nil -> Map.put(l1_txs, key, nil)
        %Ecto.Association.NotLoaded{} -> Map.put(l1_txs, key, nil)
        value -> Map.put(l1_txs, key, %{hash: value.hash, ts: value.timestamp})
      end
    end)
  end

  # Inspects L1 transactions of the batch to determine the batch status.
  #
  # ## Parameters
  # - `zksync_item`: A batch, transaction, or block.
  #
  # ## Returns
  # A string with one of predefined statuses
  defp batch_status(zksync_item) do
    cond do
      specified?(zksync_item.execute_transaction) -> "Executed on L1"
      specified?(zksync_item.prove_transaction) -> "Validated on L1"
      specified?(zksync_item.commit_transaction) -> "Sent to L1"
      # Batch entity itself has no batch_number
      not Map.has_key?(zksync_item, :batch_number) -> "Sealed on L2"
      not is_nil(zksync_item.batch_number) -> "Sealed on L2"
      true -> "Processed on L2"
    end
  end

  # Checks if an item associated with a DB entity has actual value
  #
  # ## Parameters
  # - `associated_item`: an item associated with a DB entity
  #
  # ## Returns
  # - `false`: if the item is nil or not loaded
  # - `true`: if the item has actual value
  defp specified?(associated_item) do
    case associated_item do
      nil -> false
      %Ecto.Association.NotLoaded{} -> false
      _ -> true
    end
  end

  # Gets the value of an element nested in a map using two keys.
  #
  # Clarification: Returns `map[key1][key2]`
  #
  # ## Parameters
  # - `map`: The high-level map.
  # - `key1`: The key of the element in `map`.
  # - `key2`: The key of the element in the map accessible by `map[key1]`.
  #
  # ## Returns
  # The value of the element, or `nil` if the map accessible by `key1` does not exist.
  defp get_2map_data(map, key1, key2) do
    case Map.get(map, key1) do
      nil -> nil
      inner_map -> Map.get(inner_map, key2)
    end
  end
end
