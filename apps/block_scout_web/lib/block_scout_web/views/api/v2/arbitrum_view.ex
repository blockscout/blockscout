defmodule BlockScoutWeb.API.V2.ArbitrumView do
  use BlockScoutWeb, :view

  alias BlockScoutWeb.API.V2.Helper, as: APIV2Helper
  alias Explorer.Chain.{Block, Transaction}
  alias Explorer.Chain.Arbitrum.{L1Batch, LifecycleTransaction}

  @doc """
    Function to render GET requests to `/api/v2/arbitrum/messages/:direction` endpoint.
  """
  @spec render(binary(), map()) :: map() | non_neg_integer()
  def render("arbitrum_messages.json", %{
        messages: messages,
        next_page_params: next_page_params
      }) do
    messages_out =
      messages
      |> Enum.map(fn msg ->
        %{
          "id" => msg.message_id,
          "originator_address" => msg.originator_address,
          "originating_tx_hash" => msg.originating_tx_hash,
          "origination_timestamp" => msg.origination_timestamp,
          "originating_tx_blocknum" => msg.originating_tx_blocknum,
          "completion_tx_hash" => msg.completion_tx_hash,
          "status" => msg.status
        }
      end)

    %{
      items: messages_out,
      next_page_params: next_page_params
    }
  end

  @doc """
    Function to render GET requests to `/api/v2/main-page/arbitrum/messages/to-rollup` endpoint.
  """
  def render("arbitrum_messages.json", %{messages: messages}) do
    messages_out =
      messages
      |> Enum.map(fn msg ->
        %{
          "originating_tx_hash" => msg.originating_tx_hash,
          "origination_timestamp" => msg.origination_timestamp,
          "originating_tx_blocknum" => msg.originating_tx_blocknum,
          "completion_tx_hash" => msg.completion_tx_hash
        }
      end)

    %{items: messages_out}
  end

  @doc """
    Function to render GET requests to `/api/v2/arbitrum/messages/:direction/count` endpoint.
  """
  def render("arbitrum_messages_count.json", %{count: count}) do
    count
  end

  @doc """
    Function to render GET requests to `/api/v2/arbitrum/batches/:batch_number` endpoint.
  """
  def render("arbitrum_batch.json", %{batch: batch}) do
    %{
      "number" => batch.number,
      "tx_count" => batch.tx_count,
      "start_block" => batch.start_block,
      "end_block" => batch.end_block,
      "before_acc" => batch.before_acc,
      "after_acc" => batch.after_acc
    }
    |> add_l1_tx_info(batch)
  end

  @doc """
    Function to render GET requests to `/api/v2/arbitrum/batches` endpoint.
  """
  def render("arbitrum_batches.json", %{
        batches: batches,
        next_page_params: next_page_params
      }) do
    %{
      items: render_arbitrum_batches(batches),
      next_page_params: next_page_params
    }
  end

  @doc """
    Function to render GET requests to `/api/v2/main-page/arbitrum/batches/committed` endpoint.
  """
  def render("arbitrum_batches.json", %{batches: batches}) do
    %{items: render_arbitrum_batches(batches)}
  end

  @doc """
    Function to render GET requests to `/api/v2/arbitrum/batches/count` endpoint.
  """
  def render("arbitrum_batches_count.json", %{count: count}) do
    count
  end

  @doc """
    Function to render GET requests to `/api/v2/main-page/arbitrum/batches/latest-number` endpoint.
  """
  def render("arbitrum_batch_latest_number.json", %{number: number}) do
    number
  end

  # Transforms a list of L1 batches into a map format for HTTP response.
  #
  # This function processes a list of Arbitrum L1 batches and converts each batch into
  # a map that includes basic batch information and details of the associated
  # transaction that committed the batch to L1.
  #
  # ## Parameters
  # - `batches`: A list of `Explorer.Chain.Arbitrum.L1Batch` entries.
  #
  # ## Returns
  # - A list of maps with detailed information about each batch, formatted for use
  #   in JSON HTTP responses.
  @spec render_arbitrum_batches([L1Batch]) :: [map()]
  defp render_arbitrum_batches(batches) do
    Enum.map(batches, fn batch ->
      %{
        "number" => batch.number,
        "tx_count" => batch.tx_count,
        "block_count" => batch.end_block - batch.start_block + 1
      }
      |> add_l1_tx_info(batch)
    end)
  end

  @doc """
    Extends the json output with a sub-map containing information related
    Arbitrum: batch number, associated L1 transactions, including their
    timestmaps and finalization status, and the direction if the transaction
    is a cross-chain message.

    ## Parameters
    - `out_json`: a map defining output json which will be extended
    - `transaction`: transaction structure containing Arbitrum related data

    ## Returns
    A map extended with data related Arbitrum rollup
  """
  @spec extend_transaction_json_response(map(), %{
          :__struct__ => Transaction,
          :arbitrum_batch => any(),
          :arbitrum_commit_transaction => any(),
          :arbitrum_confirm_transaction => any(),
          :arbitrum_message_to_l2 => any(),
          :arbitrum_message_from_l2 => any(),
          optional(any()) => any()
        }) :: map()
  def extend_transaction_json_response(out_json, %Transaction{} = transaction) do
    base_output = do_add_arbitrum_info(out_json, transaction)

    Map.put(base_output, "arbitrum", extend_if_message(base_output["arbitrum"], transaction))
  end

  @doc """
    Extends the json output with a sub-map containing information related
    Arbitrum: batch number and associated L1 transactions, their timestmaps
    and finalization status.

    ## Parameters
    - `out_json`: a map defining output json which will be extended
    - `block`: block structure containing Arbitrum related data

    ## Returns
    A map extended with data related Arbitrum rollup
  """
  @spec extend_block_json_response(map(), %{
          :__struct__ => Block,
          :arbitrum_batch => any(),
          :arbitrum_commit_transaction => any(),
          :arbitrum_confirm_transaction => any(),
          optional(any()) => any()
        }) :: map()
  def extend_block_json_response(out_json, %Block{} = block) do
    do_add_arbitrum_info(out_json, block)
  end

  # Adds Arbitrum-related information such as batch number and L1 transaction details to JSON.
  @spec do_add_arbitrum_info(map(), %{
          :__struct__ => Block | Transaction,
          :arbitrum_batch => any(),
          :arbitrum_commit_transaction => any(),
          :arbitrum_confirm_transaction => any(),
          optional(any()) => any()
        }) :: map()
  defp do_add_arbitrum_info(out_json, arbitrum_entity) do
    res =
      %{}
      |> add_l1_txs_info_and_status(%{
        batch_number: get_batch_number(arbitrum_entity),
        commit_transaction: arbitrum_entity.arbitrum_commit_transaction,
        confirm_transaction: arbitrum_entity.arbitrum_confirm_transaction
      })
      |> Map.put("batch_number", get_batch_number(arbitrum_entity))

    Map.put(out_json, "arbitrum", res)
  end

  # Retrieves the batch number from an Arbitrum block or transaction if the batch
  # data is loaded.
  @spec get_batch_number(%{
          :__struct__ => Block | Transaction,
          :arbitrum_batch => any(),
          optional(any()) => any()
        }) :: nil | non_neg_integer()
  defp get_batch_number(arbitrum_entity) do
    case Map.get(arbitrum_entity, :arbitrum_batch) do
      nil -> nil
      %Ecto.Association.NotLoaded{} -> nil
      value -> value.number
    end
  end

  # Augments an output JSON with commit transaction details and its status.
  @spec add_l1_tx_info(map(), %{
          :__struct__ => L1Batch,
          :commit_transaction => any(),
          optional(any()) => any()
        }) :: map()
  defp add_l1_tx_info(out_json, %L1Batch{} = batch) do
    l1_tx = %{commit_transaction: handle_associated_l1_txs_properly(batch.commit_transaction)}

    out_json
    |> Map.merge(%{
      "commit_transaction" => %{
        "hash" => APIV2Helper.get_2map_data(l1_tx, :commit_transaction, :hash),
        "block_number" => APIV2Helper.get_2map_data(l1_tx, :commit_transaction, :block),
        "timestamp" => APIV2Helper.get_2map_data(l1_tx, :commit_transaction, :ts),
        "status" => APIV2Helper.get_2map_data(l1_tx, :commit_transaction, :status)
      }
    })
  end

  # Augments an output JSON with commit and confirm transaction details and their statuses.
  @spec add_l1_txs_info_and_status(map(), %{
          :commit_transaction => any(),
          :confirm_transaction => any(),
          optional(:batch_number) => any()
        }) :: map()
  defp add_l1_txs_info_and_status(out_json, arbitrum_item)
       when is_map(arbitrum_item) and
              is_map_key(arbitrum_item, :commit_transaction) and
              is_map_key(arbitrum_item, :confirm_transaction) do
    l1_txs = get_associated_l1_txs(arbitrum_item)

    out_json
    |> Map.merge(%{
      "status" => block_or_transaction_status(arbitrum_item),
      "commit_transaction" => %{
        "hash" => APIV2Helper.get_2map_data(l1_txs, :commit_transaction, :hash),
        "timestamp" => APIV2Helper.get_2map_data(l1_txs, :commit_transaction, :ts),
        "status" => APIV2Helper.get_2map_data(l1_txs, :commit_transaction, :status)
      },
      "confirm_transaction" => %{
        "hash" => APIV2Helper.get_2map_data(l1_txs, :confirm_transaction, :hash),
        "timestamp" => APIV2Helper.get_2map_data(l1_txs, :confirm_transaction, :ts),
        "status" => APIV2Helper.get_2map_data(l1_txs, :confirm_transaction, :status)
      }
    })
  end

  # Extract transaction hash and block number, timestamp, finalization status for
  # L1 transactions associated with an Arbitrum rollup entity: transaction or block.
  #
  # ## Parameters
  # - `arbitrum_item`: a short description of a transaction, or block.
  #
  # ## Returns
  # A map containing nesting maps describing corresponding L1 transactions
  @spec get_associated_l1_txs(%{
          :commit_transaction => any(),
          :confirm_transaction => any(),
          optional(any()) => any()
        }) :: %{
          :commit_transaction =>
            nil
            | %{
                :hash => nil | binary(),
                :block_number => nil | non_neg_integer(),
                :ts => nil | DateTime.t(),
                :status => nil | :finalized | :unfinalized
              },
          :confirm_transaction =>
            nil
            | %{
                :hash => nil | binary(),
                :block_number => nil | non_neg_integer(),
                :ts => nil | DateTime.t(),
                :status => nil | :finalized | :unfinalized
              }
        }
  defp get_associated_l1_txs(arbitrum_item) do
    [:commit_transaction, :confirm_transaction]
    |> Enum.reduce(%{}, fn key, l1_txs ->
      Map.put(l1_txs, key, handle_associated_l1_txs_properly(Map.get(arbitrum_item, key)))
    end)
  end

  # Returns details of an associated L1 transaction or nil if not loaded or not available.
  @spec handle_associated_l1_txs_properly(LifecycleTransaction | Ecto.Association.NotLoaded.t() | nil) ::
          nil
          | %{
              :hash => nil | binary(),
              :block => nil | non_neg_integer(),
              :ts => nil | DateTime.t(),
              :status => nil | :finalized | :unfinalized
            }
  defp handle_associated_l1_txs_properly(associated_l1_tx) do
    case associated_l1_tx do
      nil -> nil
      %Ecto.Association.NotLoaded{} -> nil
      value -> %{hash: value.hash, block: value.block, ts: value.timestamp, status: value.status}
    end
  end

  # Inspects L1 transactions of a rollup block or transaction to determine its status.
  #
  # ## Parameters
  # - `arbitrum_item`: An Arbitrum transaction or block.
  #
  # ## Returns
  # A string with one of predefined statuses
  @spec block_or_transaction_status(%{
          :commit_transaction => any(),
          :confirm_transaction => any(),
          optional(:batch_number) => any()
        }) :: String.t()
  defp block_or_transaction_status(arbitrum_item) do
    cond do
      APIV2Helper.specified?(arbitrum_item.confirm_transaction) -> "Confirmed on base"
      APIV2Helper.specified?(arbitrum_item.commit_transaction) -> "Sent to base"
      not is_nil(arbitrum_item.batch_number) -> "Sealed on rollup"
      true -> "Processed on rollup"
    end
  end

  # Determines if an Arbitrum transaction contains a cross-chain message and extends
  # the incoming map with the `contains_message` field to reflect the direction of
  # the message.
  #
  # ## Parameters
  # - `arbitrum_tx`: An Arbitrum transaction.
  #
  # ## Returns
  # - A map extended with a field indicating the direction of the message.
  @spec extend_if_message(map(), %{
          :__struct__ => Transaction,
          :arbitrum_message_to_l2 => any(),
          :arbitrum_message_from_l2 => any(),
          optional(any()) => any()
        }) :: map()
  defp extend_if_message(arbitrum_json, %Transaction{} = arbitrum_tx) do
    message_type =
      case {APIV2Helper.specified?(arbitrum_tx.arbitrum_message_to_l2),
            APIV2Helper.specified?(arbitrum_tx.arbitrum_message_from_l2)} do
        {true, false} -> "incoming"
        {false, true} -> "outcoming"
        _ -> nil
      end

    Map.put(arbitrum_json, "contains_message", message_type)
  end
end