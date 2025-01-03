defmodule BlockScoutWeb.API.V2.ArbitrumController do
  use BlockScoutWeb, :controller

  import BlockScoutWeb.Chain,
    only: [
      next_page_params: 4,
      paging_options: 1,
      split_list_by_page: 1,
      parse_block_hash_or_number_param: 1
    ]

  import Explorer.Chain.Arbitrum.DaMultiPurposeRecord.Helper, only: [calculate_celestia_data_key: 2]

  alias Explorer.Arbitrum.ClaimRollupMessage
  alias Explorer.Chain.Arbitrum.{L1Batch, Message}
  alias Explorer.Chain.Hash
  alias Explorer.PagingOptions

  alias Explorer.Chain.Arbitrum.Reader.API.Messages, as: MessagesReader
  alias Explorer.Chain.Arbitrum.Reader.API.Settlement, as: SettlementReader

  action_fallback(BlockScoutWeb.API.V2.FallbackController)

  @batch_necessity_by_association %{:commitment_transaction => :required}

  @doc """
    Function to handle GET requests to `/api/v2/arbitrum/messages/:direction` endpoint.
  """
  @spec messages(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def messages(conn, %{"direction" => direction} = params) do
    options =
      params
      |> paging_options()

    {messages, next_page} =
      direction
      |> MessagesReader.messages(options)
      |> split_list_by_page()

    next_page_params =
      next_page_params(
        next_page,
        messages,
        params,
        fn %Message{message_id: message_id} -> %{"id" => message_id} end
      )

    conn
    |> put_status(200)
    |> render(:arbitrum_messages, %{
      messages: messages,
      next_page_params: next_page_params
    })
  end

  @doc """
    Function to handle GET requests to `/api/v2/arbitrum/messages/:direction/count` endpoint.
  """
  @spec messages_count(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def messages_count(conn, %{"direction" => direction} = _params) do
    conn
    |> put_status(200)
    |> render(:arbitrum_messages_count, %{count: MessagesReader.messages_count(direction)})
  end

  @doc """
    Function to handle GET requests to `/api/v2/arbitrum/messages/claim/:message_id` endpoint.
  """
  @spec claim_message(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def claim_message(conn, %{"message_id" => message_id} = _params) do
    message_id = String.to_integer(message_id)

    case ClaimRollupMessage.claim(message_id) do
      {:ok, [contract_address: outbox_contract_address, calldata: calldata]} ->
        conn
        |> put_status(200)
        |> render(:arbitrum_claim_message, %{calldata: calldata, address: outbox_contract_address})

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> render(:message, %{message: "cannot find requested withdrawal"})

      {:error, :sent} ->
        conn
        |> put_status(:bad_request)
        |> render(:message, %{message: "withdrawal is unconfirmed yet"})

      {:error, :initiated} ->
        conn
        |> put_status(:bad_request)
        |> render(:message, %{message: "withdrawal is just initiated, please wait a bit"})

      {:error, :relayed} ->
        conn
        |> put_status(:bad_request)
        |> render(:message, %{message: "withdrawal was executed already"})

      {:error, :internal_error} ->
        conn
        |> put_status(:not_found)
        |> render(:message, %{message: "internal error occurred"})
    end
  end

  @doc """
    Function to handle GET requests to `/api/v2/arbitrum/messages/withdrawals/:transaction_hash` endpoint.
  """
  @spec withdrawals(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def withdrawals(conn, %{"transaction_hash" => transaction_hash} = _params) do
    hash =
      case Hash.Full.cast(transaction_hash) do
        {:ok, address} -> address
        _ -> nil
      end

    withdrawals = ClaimRollupMessage.transaction_to_withdrawals(hash)

    conn
    |> put_status(200)
    |> render(:arbitrum_withdrawals, %{withdrawals: withdrawals})
  end

  @doc """
    Function to handle GET requests to `/api/v2/arbitrum/batches/:batch_number` endpoint.
  """
  @spec batch(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def batch(conn, %{"batch_number" => batch_number} = _params) do
    case SettlementReader.batch(batch_number, necessity_by_association: @batch_necessity_by_association) do
      {:ok, batch} ->
        conn
        |> put_status(200)
        |> render(:arbitrum_batch, %{batch: batch})

      {:error, :not_found} = res ->
        res
    end
  end

  @doc """
    Function to handle GET requests to `/api/v2/arbitrum/batches/da/:data_hash` or
    `/api/v2/arbitrum/batches/da/:transaction_commitment/:height` endpoints.

    For AnyTrust data hash, the function can be called in two ways:
    1. Without type parameter - returns the most recent batch for the data hash
    2. With type=all parameter - returns all batches for the data hash

    ## Parameters
    - `conn`: The connection struct
    - `params`: A map that may contain:
      * `data_hash` - The AnyTrust data hash
      * `transaction_commitment` and `height` - For Celestia data
      * `type` - Optional parameter to specify return type ("all" for all batches)
  """
  @spec batch_by_data_availability_info(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def batch_by_data_availability_info(conn, %{"data_hash" => data_hash} = params) do
    # In case of AnyTrust, `data_key` is the hash of the data itself
    case Map.get(params, "type") do
      "all" -> all_batches_by_data_availability_info(conn, data_hash, params)
      _ -> one_batch_by_data_availability_info(conn, data_hash, params)
    end
  end

  def batch_by_data_availability_info(
        conn,
        %{"transaction_commitment" => transaction_commitment, "height" => height} = _params
      ) do
    # In case of Celestia, `data_key` is the hash of the height and the commitment hash
    with {:ok, :hash, transaction_commitment_hash} <- parse_block_hash_or_number_param(transaction_commitment),
         key <- calculate_celestia_data_key(height, transaction_commitment_hash) do
      case SettlementReader.get_da_record_by_data_key(key) do
        {:ok, {batch_number, _}} ->
          batch(conn, %{"batch_number" => batch_number})

        {:error, :not_found} = res ->
          res
      end
    else
      res ->
        res
    end
  end

  # Gets the most recent batch associated with the given DA blob hash.
  #
  # ## Parameters
  # - `conn`: The connection struct
  # - `data_hash`: The AnyTrust data hash
  # - `params`: The original request parameters
  #
  # ## Returns
  # - The connection struct with rendered response
  @spec one_batch_by_data_availability_info(Plug.Conn.t(), binary(), map()) :: Plug.Conn.t()
  defp one_batch_by_data_availability_info(conn, data_hash, _params) do
    case SettlementReader.get_da_record_by_data_key(data_hash) do
      {:ok, {batch_number, _}} ->
        batch(conn, %{"batch_number" => batch_number})

      {:error, :not_found} = res ->
        res
    end
  end

  # Gets all batches associated with the given DA blob hash.
  #
  # ## Parameters
  # - `conn`: The connection struct
  # - `data_hash`: The AnyTrust data hash
  # - `params`: The original request parameters (for pagination)
  #
  # ## Returns
  # - The connection struct with rendered response
  @spec all_batches_by_data_availability_info(Plug.Conn.t(), binary(), map()) :: Plug.Conn.t()
  defp all_batches_by_data_availability_info(conn, data_hash, params) do
    case SettlementReader.get_all_da_records_by_data_key(data_hash) do
      {:ok, {batch_numbers, _}} ->
        params = Map.put(params, "batch_numbers", batch_numbers)
        batches(conn, params)

      {:error, :not_found} = res ->
        res
    end
  end

  @doc """
    Function to handle GET requests to `/api/v2/arbitrum/batches/count` endpoint.
  """
  @spec batches_count(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def batches_count(conn, _params) do
    conn
    |> put_status(200)
    |> render(:arbitrum_batches_count, %{count: SettlementReader.batches_count()})
  end

  @doc """
    Function to handle GET requests to `/api/v2/arbitrum/batches` endpoint.

    The function can be called in two ways:
    1. Without batch_numbers parameter - returns batches according to pagination parameters
    2. With batch_numbers parameter - returns only batches with specified numbers, still applying pagination

    ## Parameters
    - `conn`: The connection struct
    - `params`: A map that may contain:
      * `batch_numbers` - Optional list of specific batch numbers to retrieve
      * Standard pagination parameters
  """
  @spec batches(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def batches(conn, params) do
    {batches, next_page} =
      params
      |> paging_options()
      |> maybe_add_batch_numbers(params)
      |> Keyword.put(:necessity_by_association, @batch_necessity_by_association)
      |> SettlementReader.batches()
      |> split_list_by_page()

    next_page_params =
      next_page_params(
        next_page,
        batches,
        params,
        fn %L1Batch{number: number} -> %{"number" => number} end
      )

    conn
    |> put_status(200)
    |> render(:arbitrum_batches, %{
      batches: batches,
      next_page_params: next_page_params
    })
  end

  # Adds batch_numbers to options if they are present in params.
  #
  # ## Parameters
  # - `options`: The keyword list of options to potentially extend
  # - `params`: The params map that may contain batch_numbers
  #
  # ## Returns
  # - The options keyword list, potentially extended with batch_numbers
  @spec maybe_add_batch_numbers(Keyword.t(), map()) :: Keyword.t()
  defp maybe_add_batch_numbers(options, %{"batch_numbers" => batch_numbers}) when is_list(batch_numbers) do
    Keyword.put(options, :batch_numbers, batch_numbers)
  end

  defp maybe_add_batch_numbers(options, _params), do: options

  @doc """
    Function to handle GET requests to `/api/v2/main-page/arbitrum/batches/committed` endpoint.
  """
  @spec batches_committed(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def batches_committed(conn, _params) do
    batches =
      []
      |> Keyword.put(:necessity_by_association, @batch_necessity_by_association)
      |> Keyword.put(:committed?, true)
      |> SettlementReader.batches()

    conn
    |> put_status(200)
    |> render(:arbitrum_batches, %{batches: batches})
  end

  @doc """
    Function to handle GET requests to `/api/v2/main-page/arbitrum/batches/latest-number` endpoint.
  """
  @spec batch_latest_number(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def batch_latest_number(conn, _params) do
    conn
    |> put_status(200)
    |> render(:arbitrum_batch_latest_number, %{number: batch_latest_number()})
  end

  defp batch_latest_number do
    case SettlementReader.batch(:latest) do
      {:ok, batch} -> batch.number
      {:error, :not_found} -> 0
    end
  end

  @doc """
    Function to handle GET requests to `/api/v2/main-page/arbitrum/messages/to-rollup` endpoint.
  """
  @spec recent_messages_to_l2(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def recent_messages_to_l2(conn, _params) do
    messages = MessagesReader.relayed_l1_to_l2_messages(paging_options: %PagingOptions{page_size: 6})

    conn
    |> put_status(200)
    |> render(:arbitrum_messages, %{messages: messages})
  end
end
