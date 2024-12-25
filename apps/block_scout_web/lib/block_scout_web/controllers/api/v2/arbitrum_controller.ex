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
  alias Explorer.Chain.Arbitrum.{L1Batch, Message, Reader}
  alias Explorer.Chain.Hash
  alias Explorer.PagingOptions

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
      |> Keyword.put(:api?, true)

    {messages, next_page} =
      direction
      |> Reader.messages(options)
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
    |> render(:arbitrum_messages_count, %{count: Reader.messages_count(direction, api?: true)})
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
    case Reader.batch(
           batch_number,
           necessity_by_association: @batch_necessity_by_association,
           api?: true
         ) do
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
  """
  @spec batch_by_data_availability_info(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def batch_by_data_availability_info(conn, %{"data_hash" => data_hash} = _params) do
    # In case of AnyTrust, `data_key` is the hash of the data itself
    case Reader.get_da_record_by_data_key(data_hash, api?: true) do
      {:ok, {batch_number, _}} ->
        batch(conn, %{"batch_number" => batch_number})

      {:error, :not_found} = res ->
        res
    end
  end

  def batch_by_data_availability_info(
        conn,
        %{"transaction_commitment" => transaction_commitment, "height" => height} = _params
      ) do
    # In case of Celestia, `data_key` is the hash of the height and the commitment hash
    with {:ok, :hash, transaction_commitment_hash} <- parse_block_hash_or_number_param(transaction_commitment),
         key <- calculate_celestia_data_key(height, transaction_commitment_hash) do
      case Reader.get_da_record_by_data_key(key, api?: true) do
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

  @doc """
    Function to handle GET requests to `/api/v2/arbitrum/batches/count` endpoint.
  """
  @spec batches_count(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def batches_count(conn, _params) do
    conn
    |> put_status(200)
    |> render(:arbitrum_batches_count, %{count: Reader.batches_count(api?: true)})
  end

  @doc """
    Function to handle GET requests to `/api/v2/arbitrum/batches` endpoint.
  """
  @spec batches(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def batches(conn, params) do
    {batches, next_page} =
      params
      |> paging_options()
      |> Keyword.put(:necessity_by_association, @batch_necessity_by_association)
      |> Keyword.put(:api?, true)
      |> Reader.batches()
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

  @doc """
    Function to handle GET requests to `/api/v2/main-page/arbitrum/batches/committed` endpoint.
  """
  @spec batches_committed(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def batches_committed(conn, _params) do
    batches =
      []
      |> Keyword.put(:necessity_by_association, @batch_necessity_by_association)
      |> Keyword.put(:api?, true)
      |> Keyword.put(:committed?, true)
      |> Reader.batches()

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
    case Reader.batch(:latest, api?: true) do
      {:ok, batch} -> batch.number
      {:error, :not_found} -> 0
    end
  end

  @doc """
    Function to handle GET requests to `/api/v2/main-page/arbitrum/messages/to-rollup` endpoint.
  """
  @spec recent_messages_to_l2(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def recent_messages_to_l2(conn, _params) do
    messages = Reader.relayed_l1_to_l2_messages(paging_options: %PagingOptions{page_size: 6}, api?: true)

    conn
    |> put_status(200)
    |> render(:arbitrum_messages, %{messages: messages})
  end
end
