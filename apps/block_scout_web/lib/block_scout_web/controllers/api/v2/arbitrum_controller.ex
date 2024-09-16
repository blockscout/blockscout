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

  alias Explorer.PagingOptions
  alias Explorer.Chain.Arbitrum.{L1Batch, Message, Reader}
  alias Explorer.Chain
  alias Explorer.Chain.Log
  alias Explorer.Chain.Hash
  alias Explorer.Chain.Hash.Address
  alias Indexer.Fetcher.Arbitrum.Utils.Rpc
  alias Indexer.Helper, as: IndexerHelper

  require Logger

  action_fallback(BlockScoutWeb.API.V2.FallbackController)

  @batch_necessity_by_association %{:commitment_transaction => :required}

  # 32-byte signature of the event L2ToL1Tx(address caller, address indexed destination, uint256 indexed hash, uint256 indexed position, uint256 arbBlockNum, uint256 ethBlockNum, uint256 timestamp, uint256 callvalue, bytes data)
  @l2_to_l1_event "0x3e7aafa77dbf186b7fd488006beff893744caa3c4f6f299e8a709fa2087374fc"

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
        fn %Message{message_id: msg_id} -> %{"id" => msg_id} end
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
    Function to handle GET requests to `/api/v2/arbitrum/messages/from-rollup/:msg_id` endpoint.
  """
  @spec message_by_id(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def message_by_id(conn, %{"msg_id" => msg_id} = _params) do
    case Reader.l2_to_l1_message_with_id(msg_id) do
      nil ->
        conn
          |> put_status(:not_found)
          |> render(:message, %{message: "not found"})

      msg ->
        #Logger.warning("Received message #{inspect(msg)}")

        wdrawLogs = Chain.transaction_to_logs_by_topic0(msg.originating_transaction_hash, @l2_to_l1_event)
          #|> Enum.filter(fn log -> Hash.to_integer(log.fourth_topic) == msg_id end)

        case wdrawLogs |> Enum.at(0) do
          nil ->
            conn
              |> put_status(:not_found)
              |> render(:message, %{message: "associated L2ToL1Tx event in the transaction was not found"})

          log ->
            #hash_to_int = Hash.to_integer(log.fourth_topic)
            # Getting needed fields from the L2ToL1Tx event
            destination = case Hash.Address.cast(Hash.to_integer(log.second_topic)) do
              {:ok, address} -> address
              _ -> nil
            end

            arb_block_num = binary_slice(log.data.bytes, 32, 32)
              |> :binary.decode_unsigned()

            eth_block_num = binary_slice(log.data.bytes, 64, 32)
              |> :binary.decode_unsigned()

            l2_timestamp = binary_slice(log.data.bytes, 96, 32)
              |> :binary.decode_unsigned()

            call_value = binary_slice(log.data.bytes, 128, 32)
              |> :binary.decode_unsigned()

            data_length = binary_slice(log.data.bytes, 192, 32)
              |> :binary.decode_unsigned()

            data = binary_slice(log.data.bytes, 224, data_length)

            config_common = Application.get_all_env(:indexer)[Indexer.Fetcher.Arbitrum]
            l1_rpc = config_common[:l1_rpc]
            json_l1_rpc_named_arguments = IndexerHelper.json_rpc_named_arguments(l1_rpc)
            l1_rollup_address = config_common[:l1_rollup_address]

            #Logger.warning("l1_rollup_address: #{inspect(l1_rollup_address, pretty: true)}")
            #Logger.warning("json_rpc_named_arguments: #{inspect(json_rpc, pretty: true)}")
            #Logger.warning("Application.get_all_env(:indexer): #{inspect(Application.get_all_env(:indexer), pretty: true)}")

            latest_confirmed = Rpc.get_latest_confirmed_l2_to_l1_message_id(
              l1_rollup_address,
              json_l1_rpc_named_arguments
            )

            Logger.warning("latest confirmed: #{inspect(latest_confirmed, pretty: true)}")

            extra = [
              destination: destination,
              arb_block_num: arb_block_num,
              eth_block_num: eth_block_num,
              l2_timestamp: l2_timestamp,
              call_value: call_value,
              data: data,
            ]
            #Logger.warning("Extra data object #{inspect(extra, pretty: true)}")
            #Logger.warning("topic value: #{hash_to_int}, requested value: #{msg_id}, arbBlock: #{inspect(arb_block_num)}")
            conn
              |> put_status(200)
              |> render(:arbitrum_message, %{message: msg, data: extra})

        end
    end
  end

  @doc """
    Function to handle GET requests to `/api/v2/arbitrum/messages/:msg_id/proof` endpoint.
  """
  @spec message_proof(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def message_proof(conn, %{"msg_id" => msg_id} = _params) do
    conn
    |> put_status(200)
    |> render(:arbitrum_message_proof, %{msg_id: msg_id, proof: 456})
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
    `/api/v2/arbitrum/batches/da/:tx_commitment/:height` endpoints.
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

  def batch_by_data_availability_info(conn, %{"tx_commitment" => tx_commitment, "height" => height} = _params) do
    # In case of Celestia, `data_key` is the hash of the height and the commitment hash
    with {:ok, :hash, tx_commitment_hash} <- parse_block_hash_or_number_param(tx_commitment),
         key <- calculate_celestia_data_key(height, tx_commitment_hash) do
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
