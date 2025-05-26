defmodule BlockScoutWeb.API.V2.ArbitrumView do
  use BlockScoutWeb, :view

  alias BlockScoutWeb.API.V2.ApiView
  alias BlockScoutWeb.API.V2.Helper, as: APIV2Helper
  alias Explorer.Chain.{Block, Hash, Transaction, Wei}
  alias Explorer.Chain.Arbitrum.{L1Batch, LifecycleTransaction}
  alias Explorer.Chain.Arbitrum.Reader.API.Settlement, as: SettlementReader

  @doc """
    Function to render error\\text responses for GET requests
    to `/api/v2/arbitrum/messages/claim/:position` endpoint.
  """
  def render("message.json", assigns) do
    ApiView.render("message.json", assigns)
  end

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
          "origination_address_hash" => msg.originator_address,
          # todo: It should be removed in favour `origination_address_hash` property with the next release after 8.0.0
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
    Function to render GET requests to `/api/v2/arbitrum/messages/claim/:message_id` endpoint.
  """
  def render("arbitrum_claim_message.json", %{calldata: calldata, address: address}) do
    %{
      "calldata" => calldata,
      "outbox_address_hash" => address,
      # todo: It should be removed in favour `contract_address_hash` property with the next release after 8.0.0
      "outbox_address" => address
    }
  end

  @doc """
    Function to render GET requests to `/api/v2/arbitrum/messages/withdrawals/:transaction_hash` endpoint.
  """
  def render("arbitrum_withdrawals.json", %{withdrawals: withdrawals}) do
    withdrawals_out =
      withdrawals
      |> Enum.map(fn withdraw ->
        %{
          "id" => withdraw.message_id,
          "status" => withdraw.status,
          "caller_address_hash" => withdraw.caller,
          # todo: "caller"" should be removed in favour `caller_address_hash` property with the next release after 8.0.0
          "caller" => withdraw.caller,
          "destination_address_hash" => withdraw.destination,
          # todo: "destination" should be removed in favour `destination_address_hash` property with the next release after 8.0.0
          "destination" => withdraw.destination,
          "arb_block_number" => withdraw.arb_block_number,
          "eth_block_number" => withdraw.eth_block_number,
          "l2_timestamp" => withdraw.l2_timestamp,
          "callvalue" => Integer.to_string(withdraw.callvalue),
          "data" => withdraw.data,
          "token" =>
            case withdraw.token do
              %{} -> Map.update!(withdraw.token, :amount, &Integer.to_string/1)
              _ -> nil
            end,
          "completion_transaction_hash" => withdraw.completion_transaction_hash
        }
      end)

    %{items: withdrawals_out}
  end

  @doc """
    Function to render GET requests to `/api/v2/arbitrum/batches/:batch_number` endpoint.
  """
  def render("arbitrum_batch.json", %{batch: batch}) do
    %{
      "number" => batch.number,
      "transactions_count" => batch.transactions_count,
      "start_block_number" => batch.start_block,
      "end_block_number" => batch.end_block,
      # todo: It should be removed in favour `start_block_number` property with the next release after 8.0.0
      "start_block" => batch.start_block,
      # todo: It should be removed in favour `end_block_number` property with the next release after 8.0.0
      "end_block" => batch.end_block,
      "before_acc_hash" => batch.before_acc,
      # todo: It should be removed in favour `before_acc_hash` property with the next release after 8.0.0
      "before_acc" => batch.before_acc,
      "after_acc_hash" => batch.after_acc,
      # todo: It should be removed in favour `after_acc_hash` property with the next release after 8.0.0
      "after_acc" => batch.after_acc
    }
    |> add_l1_transaction_info(batch)
    |> add_da_info(batch)
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
  # - `batches`: A list of `Explorer.Chain.Arbitrum.L1Batch` entries or a list of maps
  #              with the corresponding fields.
  #
  # ## Returns
  # - A list of maps with detailed information about each batch, formatted for use
  #   in JSON HTTP responses.
  @spec render_arbitrum_batches(
          [L1Batch.t()]
          | [
              %{
                :number => non_neg_integer(),
                :transactions_count => non_neg_integer(),
                :start_block => non_neg_integer(),
                :end_block => non_neg_integer(),
                :batch_container => atom() | nil,
                :commitment_transaction => LifecycleTransaction.to_import(),
                optional(any()) => any()
              }
            ]
        ) :: [map()]
  defp render_arbitrum_batches(batches) do
    Enum.map(batches, &render_base_info_for_batch/1)
  end

  # Transforms a L1 batch into a map format for HTTP response.
  #
  # This function processes an Arbitrum L1 batch and converts it into a map that
  # includes basic batch information and details of the associated transaction
  # that committed the batch to L1.
  #
  # ## Parameters
  # - `batch`: Either an `Explorer.Chain.Arbitrum.L1Batch` entry or a map with
  #            the corresponding fields.
  #
  # ## Returns
  # - A  map with detailed information about the batch, formatted for use in JSON HTTP responses.
  @spec render_base_info_for_batch(
          L1Batch.t()
          | %{
              :number => non_neg_integer(),
              :transactions_count => non_neg_integer(),
              :start_block => non_neg_integer(),
              :end_block => non_neg_integer(),
              :batch_container => atom() | nil,
              :commitment_transaction => LifecycleTransaction.to_import(),
              optional(any()) => any()
            }
        ) :: map()
  def render_base_info_for_batch(batch) do
    %{
      "number" => batch.number,
      "transactions_count" => batch.transactions_count,
      "blocks_count" => batch.end_block - batch.start_block + 1,
      "batch_data_container" => batch.batch_container
    }
    |> add_l1_transaction_info(batch)
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
          optional(:arbitrum_batch) => any(),
          optional(:arbitrum_commitment_transaction) => any(),
          optional(:arbitrum_confirmation_transaction) => any(),
          optional(:arbitrum_message_to_l2) => any(),
          optional(:arbitrum_message_from_l2) => any(),
          optional(:gas_used_for_l1) => Decimal.t(),
          optional(:gas_used) => Decimal.t(),
          optional(:gas_price) => Wei.t(),
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
          optional(:arbitrum_batch) => any(),
          optional(:arbitrum_commitment_transaction) => any(),
          optional(:arbitrum_confirmation_transaction) => any(),
          optional(:send_count) => non_neg_integer(),
          optional(:send_root) => Hash.Full.t(),
          optional(:l1_block_number) => non_neg_integer(),
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
          optional(:arbitrum_batch) => any(),
          optional(:arbitrum_commitment_transaction) => any(),
          optional(:arbitrum_confirmation_transaction) => any(),
          optional(any()) => any()
        }) :: map()
  defp extend_with_settlement_info(out_json, arbitrum_entity) do
    out_json
    |> add_l1_transactions_info_and_status(%{
      batch_number: get_batch_number(arbitrum_entity),
      commitment_transaction: arbitrum_entity.arbitrum_commitment_transaction,
      confirmation_transaction: arbitrum_entity.arbitrum_confirmation_transaction
    })
    |> Map.put("batch_data_container", get_batch_data_container(arbitrum_entity))
    |> Map.put("batch_number", get_batch_number(arbitrum_entity))
  end

  # Retrieves the batch number from an Arbitrum block or transaction if the batch
  # data is loaded.
  @spec get_batch_number(%{
          :__struct__ => Block | Transaction,
          optional(:arbitrum_batch) => any(),
          optional(any()) => any()
        }) :: nil | non_neg_integer()
  defp get_batch_number(arbitrum_entity) do
    case Map.get(arbitrum_entity, :arbitrum_batch) do
      nil -> nil
      %Ecto.Association.NotLoaded{} -> nil
      value -> value.number
    end
  end

  # Retrieves the batch data container label from an Arbitrum block or transaction
  # if the batch data is loaded.
  @spec get_batch_data_container(%{
          :__struct__ => Block | Transaction,
          optional(:arbitrum_batch) => any(),
          optional(any()) => any()
        }) :: nil | String.t()
  defp get_batch_data_container(arbitrum_entity) do
    case Map.get(arbitrum_entity, :arbitrum_batch) do
      nil -> nil
      %Ecto.Association.NotLoaded{} -> nil
      value -> to_string(value.batch_container)
    end
  end

  # Augments an output JSON with commit transaction details and its status.
  @spec add_l1_transaction_info(map(), %{
          :commitment_transaction => LifecycleTransaction.t() | LifecycleTransaction.to_import(),
          optional(any()) => any()
        }) :: map()
  defp add_l1_transaction_info(out_json, %L1Batch{} = batch) do
    l1_transaction = %{commitment_transaction: handle_associated_l1_transactions_properly(batch.commitment_transaction)}

    out_json
    |> Map.merge(%{
      "commitment_transaction" => %{
        "hash" => APIV2Helper.get_2map_data(l1_transaction, :commitment_transaction, :hash),
        "block_number" => APIV2Helper.get_2map_data(l1_transaction, :commitment_transaction, :block),
        "timestamp" => APIV2Helper.get_2map_data(l1_transaction, :commitment_transaction, :ts),
        "status" => APIV2Helper.get_2map_data(l1_transaction, :commitment_transaction, :status)
      }
    })
  end

  defp add_l1_transaction_info(out_json, %{
         commitment_transaction: %{
           hash: hash,
           block_number: block_number,
           timestamp: ts,
           status: status
         }
       }) do
    out_json
    |> Map.merge(%{
      "commitment_transaction" => %{
        "hash" => %Hash{byte_count: 32, bytes: hash},
        "block_number" => block_number,
        "timestamp" => ts,
        "status" => status
      }
    })
  end

  # Adds data availability (DA) information to the given output JSON based on the batch container type.
  #
  # This function enriches the output JSON with data availability information based on
  # the type of batch container. It handles different DA types, including AnyTrust and
  # Celestia, and generates the appropriate DA data for inclusion in the output.
  #
  # ## Parameters
  # - `out_json`: The initial JSON map to be enriched with DA information.
  # - `batch`: The batch struct containing information about the rollup batch.
  #
  # ## Returns
  # - An updated JSON map containing the data availability information.
  @spec add_da_info(map(), %{
          :__struct__ => L1Batch,
          :batch_container => :in_anytrust | :in_celestia | atom() | nil,
          :number => non_neg_integer(),
          optional(any()) => any()
        }) :: map()
  defp add_da_info(out_json, %L1Batch{} = batch) do
    da_info =
      case batch.batch_container do
        nil -> %{"batch_data_container" => nil}
        :in_anytrust -> generate_anytrust_certificate(batch.number)
        :in_celestia -> generate_celestia_da_info(batch.number)
        value -> %{"batch_data_container" => to_string(value)}
      end

    out_json
    |> Map.put("data_availability", da_info)
  end

  # Generates an AnyTrust certificate for the specified batch number.
  @spec generate_anytrust_certificate(non_neg_integer()) :: map()
  defp generate_anytrust_certificate(batch_number) do
    out = %{"batch_data_container" => "in_anytrust"}

    da_info =
      with raw_info <- SettlementReader.get_da_info_by_batch_number(batch_number),
           false <- Enum.empty?(raw_info) do
        prepare_anytrust_certificate(raw_info)
      else
        _ -> %{"data_hash" => nil, "timeout" => nil, "bls_signature" => nil, "signers" => []}
      end

    out
    |> Map.merge(da_info)
  end

  # Prepares an AnyTrust certificate from the given DA information.
  #
  # This function retrieves the corresponding AnyTrust keyset based on the provided
  # DA information, constructs a list of signers and the signers' mask, and assembles
  # the certificate data.
  #
  # ## Parameters
  # - `da_info`: A map containing the DA information, including the keyset hash, data
  #   hash, timeout, aggregated BLS signature, and signers' mask.
  #
  # ## Returns
  # - A map representing the AnyTrust certificate, containing the data hash, data
  #   availability timeout, aggregated BLS signature, and the list of committee
  #   members who guaranteed availability of data for the specified timeout.
  @spec prepare_anytrust_certificate(map()) :: map()
  defp prepare_anytrust_certificate(da_info) do
    keyset = SettlementReader.get_anytrust_keyset(da_info["keyset_hash"])

    signers =
      if Enum.empty?(keyset) do
        []
      else
        signers_mask = da_info["signers_mask"]

        # Matches the signers' mask with the keyset to extract the list of signers.
        keyset["pubkeys"]
        |> Enum.with_index()
        |> Enum.filter(fn {_, index} -> Bitwise.band(signers_mask, Bitwise.bsl(1, index)) != 0 end)
        |> Enum.map(fn {pubkey, _} -> pubkey end)
      end

    %{
      "data_hash" => da_info["data_hash"],
      "timeout" => da_info["timeout"],
      "bls_signature" => da_info["bls_signature"],
      "signers" => signers
    }
  end

  # Generates Celestia DA information for the given batch number.
  @spec generate_celestia_da_info(non_neg_integer()) :: map()
  defp generate_celestia_da_info(batch_number) do
    out = %{"batch_data_container" => "in_celestia"}

    da_info = SettlementReader.get_da_info_by_batch_number(batch_number)

    out
    |> Map.merge(%{
      "height" => Map.get(da_info, "height"),
      "transaction_commitment" => Map.get(da_info, "transaction_commitment")
    })
  end

  # Augments an output JSON with commit and confirm transaction details and their statuses.
  @spec add_l1_transactions_info_and_status(map(), %{
          optional(:commitment_transaction) => any(),
          optional(:confirmation_transaction) => any(),
          optional(:batch_number) => any()
        }) :: map()
  defp add_l1_transactions_info_and_status(out_json, arbitrum_item)
       when is_map(arbitrum_item) and
              is_map_key(arbitrum_item, :commitment_transaction) and
              is_map_key(arbitrum_item, :confirmation_transaction) do
    l1_transactions = get_associated_l1_transactions(arbitrum_item)

    out_json
    |> Map.merge(%{
      "status" => block_or_transaction_status(arbitrum_item),
      "commitment_transaction" => %{
        "hash" => APIV2Helper.get_2map_data(l1_transactions, :commitment_transaction, :hash),
        "timestamp" => APIV2Helper.get_2map_data(l1_transactions, :commitment_transaction, :ts),
        "status" => APIV2Helper.get_2map_data(l1_transactions, :commitment_transaction, :status)
      },
      "confirmation_transaction" => %{
        "hash" => APIV2Helper.get_2map_data(l1_transactions, :confirmation_transaction, :hash),
        "timestamp" => APIV2Helper.get_2map_data(l1_transactions, :confirmation_transaction, :ts),
        "status" => APIV2Helper.get_2map_data(l1_transactions, :confirmation_transaction, :status)
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
  @spec get_associated_l1_transactions(%{
          optional(:commitment_transaction) => any(),
          optional(:confirmation_transaction) => any(),
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
  defp get_associated_l1_transactions(arbitrum_item) do
    [:commitment_transaction, :confirmation_transaction]
    |> Enum.reduce(%{}, fn key, l1_transactions ->
      Map.put(l1_transactions, key, handle_associated_l1_transactions_properly(Map.get(arbitrum_item, key)))
    end)
  end

  # Returns details of an associated L1 transaction or nil if not loaded or not available.
  @spec handle_associated_l1_transactions_properly(LifecycleTransaction | Ecto.Association.NotLoaded.t() | nil) ::
          nil
          | %{
              :hash => nil | binary(),
              :block => nil | non_neg_integer(),
              :ts => nil | DateTime.t(),
              :status => nil | :finalized | :unfinalized
            }
  defp handle_associated_l1_transactions_properly(associated_l1_transaction) do
    case associated_l1_transaction do
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
          optional(:commitment_transaction) => any(),
          optional(:confirmation_transaction) => any(),
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
  # the incoming map with fields related to the cross-chain message to reflect the
  # direction of the message, its status and the associated L1 transaction.
  #
  # ## Parameters
  # - `arbitrum_transaction`: An Arbitrum transaction.
  #
  # ## Returns
  # - A map extended with fields indicating the direction of the message, its status
  #   and the associated L1 transaction.
  @spec extend_if_message(map(), %{
          :__struct__ => Transaction,
          optional(:arbitrum_message_to_l2) => any(),
          optional(:arbitrum_message_from_l2) => any(),
          optional(any()) => any()
        }) :: map()
  defp extend_if_message(arbitrum_json, %Transaction{} = arbitrum_transaction) do
    {message_type, message_data} =
      case {APIV2Helper.specified?(Map.get(arbitrum_transaction, :arbitrum_message_to_l2)),
            APIV2Helper.specified?(Map.get(arbitrum_transaction, :arbitrum_message_from_l2))} do
        {true, false} ->
          {"incoming", l1_transaction_and_status_for_message(arbitrum_transaction, :incoming)}

        {false, true} ->
          {"outcoming", l1_transaction_and_status_for_message(arbitrum_transaction, :outcoming)}

        _ ->
          {nil, %{}}
      end

    arbitrum_json
    |> Map.put("contains_message", message_type)
    |> Map.put("message_related_info", message_data)
  end

  # Determines the associated L1 transaction and its status for the given message direction.
  # TODO: it's need to take into account the tx on L2 may initiate several withdrawals.
  #       The current architecture doesn't support that.
  @spec l1_transaction_and_status_for_message(
          %{
            :__struct__ => Transaction,
            optional(:arbitrum_message_to_l2) => any(),
            optional(:arbitrum_message_from_l2) => any(),
            optional(any()) => any()
          },
          :incoming | :outcoming
        ) :: map()
  defp l1_transaction_and_status_for_message(arbitrum_transaction, message_direction) do
    {l1_transaction, status} =
      case message_direction do
        :incoming ->
          l1_transaction =
            APIV2Helper.get_2map_data(arbitrum_transaction, :arbitrum_message_to_l2, :originating_transaction_hash)

          if is_nil(l1_transaction) do
            {nil, "Syncing with base layer"}
          else
            {l1_transaction, "Relayed"}
          end

        :outcoming ->
          case APIV2Helper.get_2map_data(arbitrum_transaction, :arbitrum_message_from_l2, :status) do
            :initiated ->
              {nil, "Settlement pending"}

            :sent ->
              {nil, "Waiting for confirmation"}

            :confirmed ->
              {nil, "Ready for relay"}

            :relayed ->
              {APIV2Helper.get_2map_data(arbitrum_transaction, :arbitrum_message_from_l2, :completion_transaction_hash),
               "Relayed"}
          end
      end

    %{
      "message_id" => APIV2Helper.get_2map_data(arbitrum_transaction, :arbitrum_message_from_l2, :message_id),
      "associated_l1_transaction_hash" => l1_transaction,
      # todo: It should be removed in favour `associated_l1_transaction_hash` property with the next release after 8.0.0
      "associated_l1_transaction" => l1_transaction,
      "message_status" => status
    }
  end

  # Extends the output JSON with information from Arbitrum-specific fields of the transaction.
  @spec extend_with_transaction_info(map(), %{
          :__struct__ => Transaction,
          optional(:gas_used_for_l1) => Decimal.t(),
          optional(any()) => any()
        }) :: map()
  defp extend_with_transaction_info(out_json, %Transaction{} = arbitrum_transaction) do
    # Map.get is only needed for the case when the module is compiled with
    # chain_type different from "arbitrum", `|| 0` is used to avoid nil values
    # for the transaction prior to the migration to Arbitrum specific BS build.
    gas_used_for_l1 = Map.get(arbitrum_transaction, :gas_used_for_l1) || Decimal.new(0)

    gas_used = Map.get(arbitrum_transaction, :gas_used) || Decimal.new(0)
    gas_price = Map.get(arbitrum_transaction, :gas_price) || %Wei{value: Decimal.new(0)}

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
          optional(:send_count) => non_neg_integer(),
          optional(:send_root) => Hash.Full.t(),
          optional(:l1_block_number) => non_neg_integer(),
          optional(any()) => any()
        }) :: map()
  defp extend_with_block_info(out_json, %Block{} = arbitrum_block) do
    out_json
    |> Map.put("delayed_messages", Hash.to_integer(arbitrum_block.nonce))
    |> Map.put("l1_block_number", Map.get(arbitrum_block, :l1_block_number))
    # todo: It should be removed in favour `l1_block_number` property with the next release after 8.0.0
    |> Map.put("l1_block_height", Map.get(arbitrum_block, :l1_block_number))
    |> Map.put("send_count", Map.get(arbitrum_block, :send_count))
    |> Map.put("send_root", Map.get(arbitrum_block, :send_root))
  end
end
