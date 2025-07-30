defmodule BlockScoutWeb.API.V2.ZkSyncView do
  use BlockScoutWeb, :view

  alias Explorer.Chain.{Block, Transaction}
  alias Explorer.Chain.ZkSync.TransactionBatch

  alias BlockScoutWeb.API.V2.Helper, as: APIV2Helper

  @doc """
    Function to render GET requests to `/api/v2/zksync/batches/:batch_number` endpoint.
  """
  @spec render(binary(), map()) :: map() | non_neg_integer()
  def render("zksync_batch.json", %{batch: batch}) do
    %{
      "number" => batch.number,
      "timestamp" => batch.timestamp,
      "root_hash" => batch.root_hash,
      "l1_transactions_count" => batch.l1_transaction_count,
      # todo: It should be removed in favour `l1_transactions_count` property with the next release after 8.0.0
      "l1_transaction_count" => batch.l1_transaction_count,
      "l2_transactions_count" => batch.l2_transaction_count,
      # todo: It should be removed in favour `l2_transactions_count` property with the next release after 8.0.0
      "l2_transaction_count" => batch.l2_transaction_count,
      "l1_gas_price" => batch.l1_gas_price,
      "l2_fair_gas_price" => batch.l2_fair_gas_price,
      "start_block_number" => batch.start_block,
      "end_block_number" => batch.end_block,
      # todo: It should be removed in favour `start_block_number` property with the next release after 8.0.0
      "start_block" => batch.start_block,
      # todo: It should be removed in favour `end_block_number` property with the next release after 8.0.0
      "end_block" => batch.end_block
    }
    |> add_l1_transactions_info_and_status(batch)
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
        "transactions_count" => batch.l1_transaction_count + batch.l2_transaction_count,
        # todo: It should be removed in favour `transactions_count` property with the next release after 8.0.0
        "transaction_count" => batch.l1_transaction_count + batch.l2_transaction_count
      }
      |> add_l1_transactions_info_and_status(batch)
    end)
  end

  @doc """
    Extends the json output with a sub-map containing information related
    zksync: batch number and associated L1 transactions and their timestamps.

    ## Parameters
    - `out_json`: a map defining output json which will be extended
    - `transaction`: transaction structure containing zksync related data

    ## Returns
    A map extended with data related zksync rollup
  """
  @spec extend_transaction_json_response(map(), %{
          :__struct__ => Explorer.Chain.Transaction,
          optional(:zksync_batch) => any(),
          optional(:zksync_commit_transaction) => any(),
          optional(:zksync_execute_transaction) => any(),
          optional(:zksync_prove_transaction) => any(),
          optional(any()) => any()
        }) :: map()
  def extend_transaction_json_response(out_json, %Transaction{} = transaction) do
    do_add_zksync_info(out_json, transaction)
  end

  @doc """
    Extends the json output with a sub-map containing information related
    zksync: batch number and associated L1 transactions and their timestamps.

    ## Parameters
    - `out_json`: a map defining output json which will be extended
    - `block`: block structure containing zksync related data

    ## Returns
    A map extended with data related zksync rollup
  """
  @spec extend_block_json_response(map(), %{
          :__struct__ => Explorer.Chain.Block,
          optional(:zksync_batch) => any(),
          optional(:zksync_commit_transaction) => any(),
          optional(:zksync_execute_transaction) => any(),
          optional(:zksync_prove_transaction) => any(),
          optional(any()) => any()
        }) :: map()
  def extend_block_json_response(out_json, %Block{} = block) do
    do_add_zksync_info(out_json, block)
  end

  defp do_add_zksync_info(out_json, zksync_entity) do
    res =
      %{}
      |> do_add_l1_transactions_info_and_status(%{
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

  defp add_l1_transactions_info_and_status(out_json, %TransactionBatch{} = batch) do
    do_add_l1_transactions_info_and_status(out_json, batch)
  end

  defp do_add_l1_transactions_info_and_status(out_json, zksync_item) do
    l1_transactions = get_associated_l1_transactions(zksync_item)

    out_json
    |> Map.merge(%{
      "status" => batch_status(zksync_item),
      "commit_transaction_hash" => APIV2Helper.get_2map_data(l1_transactions, :commit_transaction, :hash),
      "commit_transaction_timestamp" => APIV2Helper.get_2map_data(l1_transactions, :commit_transaction, :ts),
      "prove_transaction_hash" => APIV2Helper.get_2map_data(l1_transactions, :prove_transaction, :hash),
      "prove_transaction_timestamp" => APIV2Helper.get_2map_data(l1_transactions, :prove_transaction, :ts),
      "execute_transaction_hash" => APIV2Helper.get_2map_data(l1_transactions, :execute_transaction, :hash),
      "execute_transaction_timestamp" => APIV2Helper.get_2map_data(l1_transactions, :execute_transaction, :ts)
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
  defp get_associated_l1_transactions(zksync_item) do
    [:commit_transaction, :prove_transaction, :execute_transaction]
    |> Enum.reduce(%{}, fn key, l1_transactions ->
      case Map.get(zksync_item, key) do
        nil -> Map.put(l1_transactions, key, nil)
        %Ecto.Association.NotLoaded{} -> Map.put(l1_transactions, key, nil)
        value -> Map.put(l1_transactions, key, %{hash: value.hash, ts: value.timestamp})
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
      APIV2Helper.specified?(zksync_item.execute_transaction) -> "Executed on L1"
      APIV2Helper.specified?(zksync_item.prove_transaction) -> "Validated on L1"
      APIV2Helper.specified?(zksync_item.commit_transaction) -> "Sent to L1"
      # Batch entity itself has no batch_number
      not Map.has_key?(zksync_item, :batch_number) -> "Sealed on L2"
      not is_nil(zksync_item.batch_number) -> "Sealed on L2"
      true -> "Processed on L2"
    end
  end

  @doc """
  Returns a list of possible batch statuses.
  """
  @spec batch_status_enum() :: [String.t()]
  def batch_status_enum do
    ["Executed on L1", "Validated on L1", "Sent to L1", "Sealed on L2", "Processed on L2"]
  end
end
