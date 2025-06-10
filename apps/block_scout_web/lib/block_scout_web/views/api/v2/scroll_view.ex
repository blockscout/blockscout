defmodule BlockScoutWeb.API.V2.ScrollView do
  use BlockScoutWeb, :view

  alias BlockScoutWeb.API.V2.TransactionView
  alias Explorer.Chain.Scroll.{Batch, L1FeeParam, Reader}
  alias Explorer.Chain.{Data, Transaction}

  @api_true [api?: true]

  @doc """
    Function to render GET requests to `/api/v2/scroll/deposits` and `/api/v2/scroll/withdrawals` endpoints.
  """
  @spec render(binary(), map()) :: map() | non_neg_integer()
  def render("scroll_bridge_items.json", %{
        items: items,
        next_page_params: next_page_params,
        type: type
      }) do
    %{
      items:
        Enum.map(items, fn item ->
          {origination_transaction_hash, completion_transaction_hash} =
            if type == :deposits do
              {item.l1_transaction_hash, item.l2_transaction_hash}
            else
              {item.l2_transaction_hash, item.l1_transaction_hash}
            end

          %{
            "id" => item.index,
            "origination_transaction_hash" => origination_transaction_hash,
            "origination_timestamp" => item.block_timestamp,
            "origination_transaction_block_number" => item.block_number,
            "completion_transaction_hash" => completion_transaction_hash,
            "value" => item.amount
          }
        end),
      next_page_params: next_page_params
    }
  end

  @doc """
    Function to render GET requests to `/api/v2/scroll/deposits/count` and `/api/v2/scroll/withdrawals/count` endpoints.
  """
  def render("scroll_bridge_items_count.json", %{count: count}) do
    count
  end

  @doc """
    Function to render GET requests to `/api/v2/scroll/batches/:number` endpoint.
  """
  def render("scroll_batch.json", %{batch: batch}) do
    render_batch(batch)
  end

  @doc """
    Function to render GET requests to `/api/v2/scroll/batches` endpoint.
  """
  def render("scroll_batches.json", %{
        batches: batches,
        next_page_params: next_page_params
      }) do
    items =
      batches
      |> Enum.map(fn batch ->
        Task.async(fn -> render_batch(batch) end)
      end)
      |> Task.yield_many(:infinity)
      |> Enum.map(fn {_task, {:ok, item}} -> item end)

    %{
      items: items,
      next_page_params: next_page_params
    }
  end

  @doc """
    Function to render GET requests to `/api/v2/scroll/batches/count` endpoint.
  """
  def render("scroll_batches_count.json", %{count: count}) do
    count
  end

  # Transforms the batch info into a map format for HTTP response.
  #
  # ## Parameters
  # - `batch`: An instance of `Explorer.Chain.Scroll.Batch` entry.
  #
  # ## Returns
  # - A map with detailed information about the batch formatted for use
  #   in JSON HTTP response.
  @spec render_batch(Batch.t()) :: map()
  defp render_batch(batch) do
    {finalize_block_number, finalize_transaction_hash, finalize_timestamp} =
      if is_nil(batch.bundle) do
        {nil, nil, nil}
      else
        {batch.bundle.finalize_block_number, batch.bundle.finalize_transaction_hash, batch.bundle.finalize_timestamp}
      end

    {start_block_number, end_block_number, transactions_count} =
      if is_nil(batch.l2_block_range) do
        {nil, nil, nil}
      else
        {
          batch.l2_block_range.from,
          batch.l2_block_range.to,
          Transaction.transaction_count_for_block_range(batch.l2_block_range.from..batch.l2_block_range.to)
        }
      end

    %{
      "number" => batch.number,
      "commitment_transaction" => %{
        "block_number" => batch.commit_block_number,
        "hash" => batch.commit_transaction_hash,
        "timestamp" => batch.commit_timestamp
      },
      "confirmation_transaction" => %{
        "block_number" => finalize_block_number,
        "hash" => finalize_transaction_hash,
        "timestamp" => finalize_timestamp
      },
      "data_availability" => %{
        "batch_data_container" => batch.container
      },
      "start_block_number" => start_block_number,
      "end_block_number" => end_block_number,
      # todo: It should be removed in favour `start_block_number` property with the next release after 8.0.0
      "start_block" => start_block_number,
      # todo: It should be removed in favour `end_block_number` property with the next release after 8.0.0
      "end_block" => end_block_number,
      "transactions_count" => transactions_count,
      # todo: It should be removed in favour `transactions_count` property with the next release after 8.0.0
      "transaction_count" => transactions_count
    }
  end

  @doc """
    Extends the json output with a sub-map containing information related Scroll.
    For pending transactions the output is not extended.

    ## Parameters
    - `out_json`: A map defining output json which will be extended.
    - `transaction`: Transaction structure containing Scroll related data

    ## Returns
    - A map extended with the data related to Scroll rollup.
  """
  @spec extend_transaction_json_response(map(), %{
          :__struct__ => Transaction,
          :block_number => non_neg_integer() | nil,
          :index => non_neg_integer(),
          :input => Data.t(),
          optional(any()) => any()
        }) :: map()
  def extend_transaction_json_response(out_json, %Transaction{block_number: nil}) do
    # this is a pending transaction
    out_json
  end

  def extend_transaction_json_response(out_json, %Transaction{} = transaction) do
    config = Application.get_all_env(:explorer)[L1FeeParam]

    l1_fee_scalar = get_param(:scalar, transaction, config)
    l1_fee_commit_scalar = get_param(:commit_scalar, transaction, config)
    l1_fee_blob_scalar = get_param(:blob_scalar, transaction, config)
    l1_fee_overhead = get_param(:overhead, transaction, config)
    l1_base_fee = get_param(:l1_base_fee, transaction, config)
    l1_blob_base_fee = get_param(:l1_blob_base_fee, transaction, config)

    l1_gas_used = L1FeeParam.l1_gas_used(transaction, l1_fee_overhead)

    l2_fee =
      transaction
      |> Transaction.l2_fee(:wei)
      |> TransactionView.format_fee()

    l2_block_status = l2_block_status(transaction.block_number)

    params =
      %{}
      |> add_optional_transaction_field(transaction, :l1_fee)
      |> add_optional_transaction_field(transaction, :queue_index)
      |> Map.put("l1_fee_scalar", l1_fee_scalar)
      |> Map.put("l1_fee_commit_scalar", l1_fee_commit_scalar)
      |> Map.put("l1_fee_blob_scalar", l1_fee_blob_scalar)
      |> Map.put("l1_fee_overhead", l1_fee_overhead)
      |> Map.put("l1_base_fee", l1_base_fee)
      |> Map.put("l1_blob_base_fee", l1_blob_base_fee)
      |> Map.put("l1_gas_used", l1_gas_used)
      |> Map.put("l2_fee", l2_fee)
      |> Map.put("l2_block_status", l2_block_status)

    Map.put(out_json, "scroll", params)
  end

  defp add_optional_transaction_field(out_json, transaction, field) do
    case Map.get(transaction, field) do
      nil -> out_json
      value -> Map.put(out_json, Atom.to_string(field), value)
    end
  end

  # sobelow_skip ["DOS.BinToAtom"]
  defp get_param(name, transaction, config)
       when name in [:scalar, :commit_scalar, :blob_scalar, :overhead, :l1_base_fee, :l1_blob_base_fee] do
    name_init = :"#{name}#{:_init}"

    case Reader.get_l1_fee_param_for_transaction(name, transaction, @api_true) do
      nil -> config[name_init]
      value -> value
    end
  end

  @spec l2_block_status(non_neg_integer()) :: binary()
  defp l2_block_status(block_number) do
    case Reader.batch_by_l2_block_number(block_number, @api_true) do
      {_batch_number, nil} -> "Committed"
      {_batch_number, _bundle_id} -> "Finalized"
      nil -> "Confirmed by Sequencer"
    end
  end
end
