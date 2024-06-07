defmodule BlockScoutWeb.API.V2.ArbitrumView do
  use BlockScoutWeb, :view

  alias BlockScoutWeb.API.V2.Helper, as: APIV2Helper
  alias Explorer.Chain.{Block, Hash, Transaction, Wei}
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
          "origination_address" => msg.originator_address,
          "origination_transaction_hash" => msg.originating_transaction_hash,
          "origination_timestamp" => msg.origination_timestamp,
          "origination_transaction_block_number" => msg.originating_transaction_block_number,
          "completion_transaction_hash" => msg.completion_transaction_hash,
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
          "origination_transaction_hash" => msg.originating_transaction_hash,
          "origination_timestamp" => msg.origination_timestamp,
          "origination_transaction_block_number" => msg.originating_transaction_block_number,
          "completion_transaction_hash" => msg.completion_transaction_hash
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
      "transactions_count" => batch.transactions_count,
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
        "transactions_count" => batch.transactions_count,
        "block_count" => batch.end_block - batch.start_block + 1
      }
      |> add_l1_tx_info(batch)
    end)
  end

  @doc """
    Extends the json output with a sub-map containing information related Arbitrum.

    ## Parameters
    - `out_json`: a map defining output json which will be extended
    - `transaction`: transaction structure containing Arbitrum related data

    ## Returns
    A map extended with data related Arbitrum rollup
  """
  @spec extend_transaction_json_response(map(), %{
          :__struct__ => Transaction,
          :arbitrum_batch => any(),
          :arbitrum_commitment_transaction => any(),
          :arbitrum_confirmation_transaction => any(),
          :arbitrum_message_to_l2 => any(),
          :arbitrum_message_from_l2 => any(),
          :gas_used_for_l1 => Decimal.t(),
          :gas_used => Decimal.t(),
          :gas_price => Wei.t(),
          optional(any()) => any()
        }) :: map()
  def extend_transaction_json_response(out_json, %Transaction{} = transaction) do
    arbitrum_info =
      %{}
      |> extend_with_settlement_info(transaction)
      |> extend_if_message(transaction)
      |> extend_with_transaction_info(transaction)

    Map.put(out_json, "arbitrum", arbitrum_info)
  end

  @doc """
    Extends the json output with a sub-map containing information related Arbitrum.

    ## Parameters
    - `out_json`: a map defining output json which will be extended
    - `block`: block structure containing Arbitrum related data

    ## Returns
    A map extended with data related Arbitrum rollup
  """
  @spec extend_block_json_response(map(), %{
          :__struct__ => Block,
          :arbitrum_batch => any(),
          :arbitrum_commitment_transaction => any(),
          :arbitrum_confirmation_transaction => any(),
          :nonce => Hash.Nonce.t(),
          :send_count => non_neg_integer(),
          :send_root => Hash.Full.t(),
          :l1_block_number => non_neg_integer(),
          optional(any()) => any()
        }) :: map()
  def extend_block_json_response(out_json, %Block{} = block) do
    arbitrum_info =
      %{}
      |> extend_with_settlement_info(block)
      |> extend_with_block_info(block)

    Map.put(out_json, "arbitrum", arbitrum_info)
  end

  # Augments an output JSON with settlement-related information such as batch number and L1 transaction details to JSON.
  @spec extend_with_settlement_info(map(), %{
          :__struct__ => Block | Transaction,
          :arbitrum_batch => any(),
          :arbitrum_commitment_transaction => any(),
          :arbitrum_confirmation_transaction => any(),
          optional(any()) => any()
        }) :: map()
  defp extend_with_settlement_info(out_json, arbitrum_entity) do
    out_json
    |> add_l1_txs_info_and_status(%{
      batch_number: get_batch_number(arbitrum_entity),
      commitment_transaction: arbitrum_entity.arbitrum_commitment_transaction,
      confirmation_transaction: arbitrum_entity.arbitrum_confirmation_transaction
    })
    |> Map.put("batch_number", get_batch_number(arbitrum_entity))
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
          :commitment_transaction => any(),
          optional(any()) => any()
        }) :: map()
  defp add_l1_tx_info(out_json, %L1Batch{} = batch) do
    l1_tx = %{commitment_transaction: handle_associated_l1_txs_properly(batch.commitment_transaction)}

    out_json
    |> Map.merge(%{
      "commitment_transaction" => %{
        "hash" => APIV2Helper.get_2map_data(l1_tx, :commitment_transaction, :hash),
        "block_number" => APIV2Helper.get_2map_data(l1_tx, :commitment_transaction, :block),
        "timestamp" => APIV2Helper.get_2map_data(l1_tx, :commitment_transaction, :ts),
        "status" => APIV2Helper.get_2map_data(l1_tx, :commitment_transaction, :status)
      }
    })
  end

  # Augments an output JSON with commit and confirm transaction details and their statuses.
  @spec add_l1_txs_info_and_status(map(), %{
          :commitment_transaction => any(),
          :confirmation_transaction => any(),
          optional(:batch_number) => any()
        }) :: map()
  defp add_l1_txs_info_and_status(out_json, arbitrum_item)
       when is_map(arbitrum_item) and
              is_map_key(arbitrum_item, :commitment_transaction) and
              is_map_key(arbitrum_item, :confirmation_transaction) do
    l1_txs = get_associated_l1_txs(arbitrum_item)

    out_json
    |> Map.merge(%{
      "status" => block_or_transaction_status(arbitrum_item),
      "commitment_transaction" => %{
        "hash" => APIV2Helper.get_2map_data(l1_txs, :commitment_transaction, :hash),
        "timestamp" => APIV2Helper.get_2map_data(l1_txs, :commitment_transaction, :ts),
        "status" => APIV2Helper.get_2map_data(l1_txs, :commitment_transaction, :status)
      },
      "confirmation_transaction" => %{
        "hash" => APIV2Helper.get_2map_data(l1_txs, :confirmation_transaction, :hash),
        "timestamp" => APIV2Helper.get_2map_data(l1_txs, :confirmation_transaction, :ts),
        "status" => APIV2Helper.get_2map_data(l1_txs, :confirmation_transaction, :status)
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
          :commitment_transaction => any(),
          :confirmation_transaction => any(),
          optional(any()) => any()
        }) :: %{
          :commitment_transaction =>
            nil
            | %{
                :hash => nil | binary(),
                :block_number => nil | non_neg_integer(),
                :ts => nil | DateTime.t(),
                :status => nil | :finalized | :unfinalized
              },
          :confirmation_transaction =>
            nil
            | %{
                :hash => nil | binary(),
                :block_number => nil | non_neg_integer(),
                :ts => nil | DateTime.t(),
                :status => nil | :finalized | :unfinalized
              }
        }
  defp get_associated_l1_txs(arbitrum_item) do
    [:commitment_transaction, :confirmation_transaction]
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
      value -> %{hash: value.hash, block: value.block_number, ts: value.timestamp, status: value.status}
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
          :commitment_transaction => any(),
          :confirmation_transaction => any(),
          optional(:batch_number) => any()
        }) :: String.t()
  defp block_or_transaction_status(arbitrum_item) do
    cond do
      APIV2Helper.specified?(arbitrum_item.confirmation_transaction) -> "Confirmed on base"
      APIV2Helper.specified?(arbitrum_item.commitment_transaction) -> "Sent to base"
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
      case {APIV2Helper.specified?(Map.get(arbitrum_tx, :arbitrum_message_to_l2)),
            APIV2Helper.specified?(Map.get(arbitrum_tx, :arbitrum_message_from_l2))} do
        {true, false} -> "incoming"
        {false, true} -> "outcoming"
        _ -> nil
      end

    Map.put(arbitrum_json, "contains_message", message_type)
  end

  # Extends the output JSON with information from Arbitrum-specific fields of the transaction.
  @spec extend_with_transaction_info(map(), %{
          :__struct__ => Transaction,
          :gas_used_for_l1 => Decimal.t(),
          :gas_used => Decimal.t(),
          :gas_price => Wei.t(),
          optional(any()) => any()
        }) :: map()
  defp extend_with_transaction_info(out_json, %Transaction{} = arbitrum_tx) do
    # These checks are only needed for the case when the module is compiled with
    # chain_type different from "arbitrum"
    gas_used_for_l1 = Map.get(arbitrum_tx, :gas_used_for_l1, 0)
    gas_used = Map.get(arbitrum_tx, :gas_used, 0)
    gas_price = Map.get(arbitrum_tx, :gas_price, 0)

    gas_used_for_l2 =
      gas_used
      |> Decimal.sub(gas_used_for_l1)

    poster_fee =
      gas_price
      |> Wei.to(:wei)
      |> Decimal.mult(gas_used_for_l1)

    network_fee =
      gas_price
      |> Wei.to(:wei)
      |> Decimal.mult(gas_used_for_l2)

    out_json
    |> Map.put("gas_used_for_l1", gas_used_for_l1)
    |> Map.put("gas_used_for_l2", gas_used_for_l2)
    |> Map.put("poster_fee", poster_fee)
    |> Map.put("network_fee", network_fee)
  end

  # Extends the output JSON with information from the Arbitrum-specific fields of the block.
  @spec extend_with_block_info(map(), %{
          :__struct__ => Block,
          :nonce => Hash.Nonce.t(),
          :send_count => non_neg_integer(),
          :send_root => Hash.Full.t(),
          :l1_block_number => non_neg_integer(),
          optional(any()) => any()
        }) :: map()
  defp extend_with_block_info(out_json, %Block{} = arbitrum_block) do
    out_json
    |> Map.put("delayed_messages", Hash.to_integer(arbitrum_block.nonce))
    |> Map.put("l1_block_height", Map.get(arbitrum_block, :l1_block_number))
    |> Map.put("send_count", Map.get(arbitrum_block, :send_count))
    |> Map.put("send_root", Map.get(arbitrum_block, :send_root))
  end
end
