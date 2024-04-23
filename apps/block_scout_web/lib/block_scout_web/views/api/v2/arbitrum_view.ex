defmodule BlockScoutWeb.API.V2.ArbitrumView do
  use BlockScoutWeb, :view

  alias BlockScoutWeb.API.V2.Helper, as: APIV2Helper
  alias Explorer.Chain.{Block, Transaction}
  # alias Explorer.Chain.Arbitrum.L1Batch

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
      |> do_add_l1_txs_info_and_status(%{
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

  # defp add_l1_txs_info_and_status(out_json, %L1Batch{} = batch) do
  #   do_add_l1_txs_info_and_status(out_json, batch)
  # end

  # Augments an output JSON with commit and confirm transaction details and their statuses.
  @spec do_add_l1_txs_info_and_status(map(), %{
          :commit_transaction => any(),
          :confirm_transaction => any(),
          optional(:batch_number) => any()
        }) :: map()
  defp do_add_l1_txs_info_and_status(out_json, arbitrum_item) do
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

  # Extract transaction hash and timestamp, finalization status for L1 transactions
  # associated with an Arbitrum rollup entity: batch, transaction or block.
  #
  # ## Parameters
  # - `arbitrum_item`: A batch, transaction, or block.
  #
  # ## Returns
  # A map containing nesting maps describing corresponding L1 transactions
  @spec get_associated_l1_txs(%{
          :commit_transaction => any(),
          :confirm_transaction => any(),
          optional(any()) => any()
        }) :: %{
          :commit_transaction => %{
            :hash => nil | binary(),
            :ts => nil | Datetime.t(),
            :status => nil | :finalized | :unfinalized
          },
          :confirm_transaction => %{
            :hash => nil | binary(),
            :ts => nil | Datetime.t(),
            :status => nil | :finalized | :unfinalized
          }
        }
  defp get_associated_l1_txs(arbitrum_item) do
    [:commit_transaction, :confirm_transaction]
    |> Enum.reduce(%{}, fn key, l1_txs ->
      case Map.get(arbitrum_item, key) do
        nil -> Map.put(l1_txs, key, nil)
        %Ecto.Association.NotLoaded{} -> Map.put(l1_txs, key, nil)
        value -> Map.put(l1_txs, key, %{hash: value.hash, ts: value.timestamp, status: value.status})
      end
    end)
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
          optional(batch_number) => any()
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
