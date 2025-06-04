defmodule BlockScoutWeb.API.V2.OptimismController do
  use BlockScoutWeb, :controller

  require Logger

  import BlockScoutWeb.Chain,
    only: [
      next_page_params: 3,
      paging_options: 1,
      split_list_by_page: 1
    ]

  import BlockScoutWeb.PagingHelper,
    only: [
      delete_parameters_from_next_page_params: 1
    ]

  import Explorer.Helper, only: [hash_to_binary: 1]

  alias BlockScoutWeb.API.V2.ApiView
  alias Explorer.Chain
  alias Explorer.Chain.Cache.ChainId
  alias Explorer.Chain.{Data, Hash, Token, Transaction}

  alias Explorer.Chain.Optimism.{
    Deposit,
    DisputeGame,
    FrameSequence,
    FrameSequenceBlob,
    InteropMessage,
    OutputRoot,
    TransactionBatch,
    Withdrawal
  }

  alias Indexer.Fetcher.Optimism.Interop.MessageQueue, as: InteropMessageQueue

  action_fallback(BlockScoutWeb.API.V2.FallbackController)

  @api_true [api?: true]

  @doc """
    Function to handle GET requests to `/api/v2/optimism/txn-batches` and
    `/api/v2/optimism/txn-batches/:l2_block_range_start/:l2_block_range_end` endpoints.
  """
  @spec transaction_batches(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def transaction_batches(conn, params) do
    {batches, next_page} =
      params
      |> paging_options()
      |> Keyword.put(:api?, true)
      |> Keyword.put(:l2_block_range_start, Map.get(params, "l2_block_range_start"))
      |> Keyword.put(:l2_block_range_end, Map.get(params, "l2_block_range_end"))
      |> TransactionBatch.list()
      |> split_list_by_page()

    next_page_params = next_page_params(next_page, batches, delete_parameters_from_next_page_params(params))

    conn
    |> put_status(200)
    |> render(:optimism_transaction_batches, %{
      batches: batches,
      next_page_params: next_page_params
    })
  end

  @doc """
    Function to handle GET requests to `/api/v2/optimism/txn-batches/count` endpoint.
  """
  @spec transaction_batches_count(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def transaction_batches_count(conn, _params) do
    items_count(conn, TransactionBatch)
  end

  @doc """
    Function to handle GET requests to `/api/v2/optimism/batches` endpoint.
  """
  @spec batches(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def batches(conn, params) do
    {batches, next_page} =
      params
      |> paging_options()
      |> Keyword.put(:api?, true)
      |> Keyword.put(:only_view_ready?, true)
      |> FrameSequence.list()
      |> split_list_by_page()

    next_page_params = next_page_params(next_page, batches, params)

    items =
      batches
      |> Enum.map(fn fs ->
        Task.async(fn ->
          l2_block_number_from = TransactionBatch.edge_l2_block_number(fs.id, :min)
          l2_block_number_to = TransactionBatch.edge_l2_block_number(fs.id, :max)

          l2_block_range =
            if not is_nil(l2_block_number_from) and not is_nil(l2_block_number_to) do
              l2_block_number_from..l2_block_number_to
            end

          # credo:disable-for-lines:2 Credo.Check.Refactor.Nesting
          transaction_count =
            case l2_block_range do
              nil -> 0
              range -> Transaction.transaction_count_for_block_range(range)
            end

          {batch_data_container, _} = FrameSequenceBlob.list(fs.id, api?: true)

          fs
          |> Map.put(:l2_block_range, l2_block_range)
          |> Map.put(:transactions_count, transaction_count)
          # todo: It should be removed in favour `transactions_count` property with the next release after 8.0.0
          |> Map.put(:transaction_count, transaction_count)
          |> Map.put(:batch_data_container, batch_data_container)
        end)
      end)
      |> Task.yield_many(:infinity)
      |> Enum.map(fn {_task, {:ok, item}} -> item end)
      |> Enum.reject(&is_nil(&1.l2_block_range))

    conn
    |> put_status(200)
    |> render(:optimism_batches, %{
      batches: items,
      next_page_params: next_page_params
    })
  end

  @doc """
    Function to handle GET requests to `/api/v2/optimism/batches/count` endpoint.
  """
  @spec batches_count(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def batches_count(conn, _params) do
    items_count(conn, FrameSequence)
  end

  @doc """
    Function to handle GET requests to `/api/v2/optimism/batches/da/celestia/:height/:commitment` endpoint.
  """
  @spec batch_by_celestia_blob(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def batch_by_celestia_blob(conn, %{"height" => height, "commitment" => commitment}) do
    {height, ""} = Integer.parse(height)

    commitment =
      if String.starts_with?(String.downcase(commitment), "0x") do
        commitment
      else
        "0x" <> commitment
      end

    batch = FrameSequence.batch_by_celestia_blob(commitment, height, api?: true)

    if is_nil(batch) do
      {:error, :not_found}
    else
      conn
      |> put_status(200)
      |> render(:optimism_batch, %{batch: batch})
    end
  end

  @doc """
    Function to handle GET requests to `/api/v2/optimism/batches/:internal_id` endpoint.
  """
  @spec batch_by_internal_id(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def batch_by_internal_id(conn, %{"internal_id" => internal_id}) do
    {internal_id, ""} = Integer.parse(internal_id)

    batch = FrameSequence.batch_by_internal_id(internal_id, api?: true)

    if is_nil(batch) do
      {:error, :not_found}
    else
      conn
      |> put_status(200)
      |> render(:optimism_batch, %{batch: batch})
    end
  end

  @doc """
    Function to handle GET requests to `/api/v2/optimism/output-roots` endpoint.
  """
  @spec output_roots(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def output_roots(conn, params) do
    {roots, next_page} =
      params
      |> paging_options()
      |> Keyword.put(:api?, true)
      |> OutputRoot.list()
      |> split_list_by_page()

    next_page_params = next_page_params(next_page, roots, params)

    conn
    |> put_status(200)
    |> render(:optimism_output_roots, %{
      roots: roots,
      next_page_params: next_page_params
    })
  end

  @doc """
    Function to handle GET requests to `/api/v2/optimism/output-roots/count` endpoint.
  """
  @spec output_roots_count(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def output_roots_count(conn, _params) do
    items_count(conn, OutputRoot)
  end

  @doc """
    Function to handle GET requests to `/api/v2/optimism/games` endpoint.
  """
  @spec games(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def games(conn, params) do
    {games, next_page} =
      params
      |> paging_options()
      |> Keyword.put(:api?, true)
      |> DisputeGame.list()
      |> split_list_by_page()

    next_page_params = next_page_params(next_page, games, params)

    conn
    |> put_status(200)
    |> render(:optimism_games, %{
      games: games,
      next_page_params: next_page_params
    })
  end

  @doc """
    Function to handle GET requests to `/api/v2/optimism/games/count` endpoint.
  """
  @spec games_count(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def games_count(conn, _params) do
    count = DisputeGame.get_last_known_index() + 1

    conn
    |> put_status(200)
    |> render(:optimism_items_count, %{count: count})
  end

  @doc """
    Function to handle GET requests to `/api/v2/optimism/deposits` endpoint.
  """
  @spec deposits(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def deposits(conn, params) do
    {deposits, next_page} =
      params
      |> paging_options()
      |> Keyword.put(:api?, true)
      |> Deposit.list()
      |> split_list_by_page()

    next_page_params = next_page_params(next_page, deposits, params)

    conn
    |> put_status(200)
    |> render(:optimism_deposits, %{
      deposits: deposits,
      next_page_params: next_page_params
    })
  end

  @doc """
    Function to handle GET requests to `/api/v2/optimism/deposits/count` endpoint.
  """
  @spec deposits_count(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def deposits_count(conn, _params) do
    items_count(conn, Deposit)
  end

  @doc """
    Function to handle GET requests to `/api/v2/optimism/interop/messages/:unique_id` endpoint.
  """
  @spec interop_message(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def interop_message(conn, params) do
    unique_id = Map.get(params, "unique_id", "")

    with true <- String.length(unique_id) == 16,
         {init_chain_id_string, nonce_string} = String.split_at(unique_id, 8),
         {init_chain_id, ""} <- Integer.parse(init_chain_id_string, 16),
         {nonce, ""} <- Integer.parse(nonce_string, 16),
         msg = InteropMessage.get_message(init_chain_id, nonce),
         false <- is_nil(msg) do
      current_chain_id =
        case ChainId.get_id() do
          nil -> Application.get_env(:block_scout_web, :chain_id)
          chain_id -> chain_id
        end

      relay_chain_id = msg.relay_chain_id

      direction =
        case current_chain_id do
          ^init_chain_id -> :out
          ^relay_chain_id -> :in
          _ -> nil
        end

      transfer_token =
        if not is_nil(msg.transfer_token_address_hash) do
          case Token.get_by_contract_address_hash(msg.transfer_token_address_hash, @api_true) do
            nil -> %{contract_address_hash: msg.transfer_token_address_hash, symbol: nil, decimals: nil}
            t -> %{contract_address_hash: t.contract_address_hash, symbol: t.symbol, decimals: t.decimals}
          end
        end

      message =
        msg
        |> InteropMessage.extend_with_status()
        |> Map.put(:init_chain, interop_chain_id_to_instance_info(msg.init_chain_id))
        |> Map.put(:relay_chain, interop_chain_id_to_instance_info(msg.relay_chain_id))
        |> Map.put(:direction, direction)
        |> Map.put(:transfer_token, transfer_token)

      conn
      |> put_status(200)
      |> render(:optimism_interop_message, %{message: message})
    else
      _ ->
        conn
        |> put_view(ApiView)
        |> put_status(:not_found)
        |> render(:message, %{message: "Invalid message id or the message with such id is not found"})
    end
  end

  # Calls `InteropMessage.interop_chain_id_to_instance_info` function and depending on the result
  # returns a map with the instance info.
  #
  # ## Parameters
  # - `chain_id`: ID of the chain the instance info is needed for.
  #
  # ## Returns
  # - A map with the instance info.
  # - If the info cannot be retrieved, anyway returns the map with a single `chain_id` item.
  @spec interop_chain_id_to_instance_info(non_neg_integer()) :: map()
  defp interop_chain_id_to_instance_info(chain_id) do
    case InteropMessage.interop_chain_id_to_instance_info(chain_id) do
      nil -> %{chain_id: chain_id}
      chain -> chain
    end
  end

  @doc """
    Function to handle GET requests to `/api/v2/optimism/interop/messages` endpoint.
  """
  @spec interop_messages(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def interop_messages(conn, params) do
    current_chain_id =
      case ChainId.get_id() do
        nil -> Application.get_env(:block_scout_web, :chain_id)
        chain_id -> chain_id
      end

    {messages, next_page} =
      params
      |> interop_extract_message_filters()
      |> Keyword.merge(paging_options(params))
      |> Keyword.merge(@api_true)
      |> Keyword.merge(current_chain_id: current_chain_id)
      |> InteropMessage.list()
      |> split_list_by_page()

    next_page_params = next_page_params(next_page, messages, Map.take(params, ["items_count"]))

    messages_extended =
      messages
      |> Enum.map(fn message ->
        message_extended =
          cond do
            message.init_chain_id != current_chain_id and not is_nil(current_chain_id) ->
              Map.put(message, :init_chain, InteropMessage.interop_chain_id_to_instance_info(message.init_chain_id))

            message.relay_chain_id != current_chain_id and not is_nil(current_chain_id) ->
              Map.put(message, :relay_chain, InteropMessage.interop_chain_id_to_instance_info(message.relay_chain_id))

            true ->
              message
          end

        InteropMessage.extend_with_status(message_extended)
      end)

    conn
    |> put_status(200)
    |> render(:optimism_interop_messages, %{
      messages: messages_extended,
      next_page_params: next_page_params
    })
  end

  @doc """
    Function to handle GET requests to `/api/v2/optimism/interop/messages/count` endpoint.
  """
  @spec interop_messages_count(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def interop_messages_count(conn, _params) do
    conn
    |> put_status(200)
    |> render(:optimism_items_count, %{count: InteropMessage.count(@api_true)})
  end

  @doc """
    Function to handle GET requests to `/api/v2/optimism/withdrawals` endpoint.
  """
  @spec withdrawals(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def withdrawals(conn, params) do
    {withdrawals, next_page} =
      params
      |> paging_options()
      |> Keyword.put(:api?, true)
      |> Withdrawal.list()
      |> split_list_by_page()

    next_page_params = next_page_params(next_page, withdrawals, params)

    conn
    |> put_status(200)
    |> render(:optimism_withdrawals, %{
      withdrawals: withdrawals,
      next_page_params: next_page_params
    })
  end

  @doc """
    Function to handle GET requests to `/api/v2/optimism/withdrawals/count` endpoint.
  """
  @spec withdrawals_count(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def withdrawals_count(conn, _params) do
    items_count(conn, Withdrawal)
  end

  @doc """
    Function to handle GET requests to `/api/v2/optimism/interop/public-key` endpoint.
  """
  @spec interop_public_key(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def interop_public_key(conn, _params) do
    env = Application.get_all_env(:indexer)[InteropMessageQueue]

    with {:ok, private_key} <- env[:private_key] |> String.trim_leading("0x") |> Base.decode16(case: :mixed),
         {:ok, public_key} <- ExSecp256k1.create_public_key(private_key) do
      conn
      |> put_status(200)
      |> render(:optimism_interop_public_key, %{public_key: %Data{bytes: public_key}})
    else
      _ ->
        Logger.error("Interop: cannot derive a public key from the private key. Private key is invalid or undefined.")

        conn
        |> put_view(ApiView)
        |> put_status(:not_found)
        |> render(:message, %{message: "private key is invalid or undefined"})
    end
  end

  @doc """
    Function to handle POST request to `/api/v2/import/optimism/interop/` endpoint.
    Accepts `init` part of the interop message from the source instance or
    `relay` part of the interop message from the target instance.
  """
  @spec interop_import(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def interop_import(
        conn,
        %{
          "sender_address_hash" => sender_address_hash,
          "target_address_hash" => target_address_hash,
          "nonce" => nonce,
          "init_chain_id" => init_chain_id,
          "init_transaction_hash" => init_transaction_hash,
          "timestamp" => timestamp_unix,
          "relay_chain_id" => relay_chain_id,
          "payload" => payload,
          "signature" => "0x" <> signature
        } = params
      )
      when is_integer(init_chain_id) do
    # accept `init` part of the interop message from the source instance
    data_to_verify =
      sender_address_hash <>
        target_address_hash <>
        Integer.to_string(nonce) <>
        Integer.to_string(init_chain_id) <>
        init_transaction_hash <> Integer.to_string(timestamp_unix) <> Integer.to_string(relay_chain_id) <> payload

    interop_import_internal(init_chain_id, data_to_verify, signature, params, &InteropMessage.get_relay_part/2, conn)
  end

  def interop_import(
        conn,
        %{
          "nonce" => nonce,
          "init_chain_id" => init_chain_id,
          "relay_chain_id" => relay_chain_id,
          "relay_transaction_hash" => relay_transaction_hash,
          "failed" => failed,
          "signature" => "0x" <> signature
        } = params
      )
      when is_integer(relay_chain_id) do
    # accept `relay` part of the interop message from the target instance
    data_to_verify =
      Integer.to_string(nonce) <>
        Integer.to_string(init_chain_id) <>
        Integer.to_string(relay_chain_id) <> relay_transaction_hash <> to_string(failed)

    interop_import_internal(relay_chain_id, data_to_verify, signature, params, &InteropMessage.get_init_part/2, conn)
  end

  # Implements import logic for the interop message's data sent to `/api/v2/import/optimism/interop/` endpoint.
  # Used by the public `interop_import` function. It requests a public key from the remote Blockscout instance,
  # then after verifying the data with this key, imports the data to database and renders missed part of the message
  # for the remote side (the request was sent from). In case of any error, responds with the corresponding HTTP code
  # and renders the corresponding error message.
  #
  # ## Parameters
  # - `remote_chain_id`: Chain ID of the remote instance which public key should be retrieved for data verifying.
  # - `data_to_verify`: Signed binary data which needs to be verified with the public key.
  # - `signature`: A string in hex representation (without 0x prefix) containing the signature.
  # - `params`: JSON parameters got from the corresponding POST request sent by the remote instance.
  # - `missed_part_fn`: Reference to the function that should return missed part of the message data (from db) for the remote side.
  # - `conn`: The connection struct.
  #
  # ## Returns
  # - The connection struct with the rendered response.
  @spec interop_import_internal(non_neg_integer(), String.t(), String.t(), map(), function(), Plug.Conn.t()) ::
          Plug.Conn.t()
  defp interop_import_internal(remote_chain_id, data_to_verify, signature, params, missed_part_fn, conn) do
    # we need to know the remote instance API URL to get public key from that
    public_key =
      remote_chain_id
      |> InteropMessage.interop_chain_id_to_instance_api_url()
      |> interop_fetch_public_key()

    with {:empty_public_key, false} <- {:empty_public_key, is_nil(public_key)},
         {:wrong_signature, false} <-
           {:wrong_signature,
            ExSecp256k1.verify(ExKeccak.hash_256(data_to_verify), Base.decode16!(signature, case: :mixed), public_key) !=
              :ok},
         # the data is verified, so now we can import that to the database
         {:ok, _} <-
           Chain.import(%{optimism_interop_messages: %{params: [interop_prepare_import(params)]}, timeout: :infinity}) do
      conn
      |> put_status(200)
      |> render(:optimism_interop_response, missed_part_fn.(params["init_chain_id"], params["nonce"]))
    else
      {:empty_public_key, true} ->
        interop_render_http_error(conn, 500, "Unable to get public key")

      {:wrong_signature, true} ->
        interop_render_http_error(conn, :unauthorized, "Wrong signature")

      _ ->
        interop_render_http_error(conn, 500, "Cannot import the data")
    end
  end

  # Prepares interop message's data to be imported to database. Converts POST request parameters to the map acceptable by `Chain.import`.
  #
  # ## Parameters
  # - `params`: JSON parameters got from the corresponding POST request sent by the remote instance.
  #
  # ## Returns
  # - Resulting map with the `op_interop_messages` table's fields.
  @spec interop_prepare_import(map()) :: map()
  defp interop_prepare_import(%{"init_transaction_hash" => init_transaction_hash} = params) do
    payload = hash_to_binary(params["payload"])

    [transfer_token_address_hash, transfer_from_address_hash, transfer_to_address_hash, transfer_amount] =
      InteropMessage.decode_payload(payload)

    %{
      sender_address_hash: params["sender_address_hash"],
      target_address_hash: params["target_address_hash"],
      nonce: params["nonce"],
      init_chain_id: params["init_chain_id"],
      init_transaction_hash: init_transaction_hash,
      timestamp: DateTime.from_unix!(params["timestamp"]),
      relay_chain_id: params["relay_chain_id"],
      payload: payload,
      transfer_token_address_hash: transfer_token_address_hash,
      transfer_from_address_hash: transfer_from_address_hash,
      transfer_to_address_hash: transfer_to_address_hash,
      transfer_amount: transfer_amount
    }
  end

  defp interop_prepare_import(%{"relay_transaction_hash" => relay_transaction_hash} = params) do
    %{
      nonce: params["nonce"],
      init_chain_id: params["init_chain_id"],
      relay_chain_id: params["relay_chain_id"],
      relay_transaction_hash: relay_transaction_hash,
      failed: params["failed"]
    }
  end

  # Gets filter parameters for message list and prepares them for `Explorer.Chain.Optimism.InteropMessage.list/1` function.
  #
  # ## Parameters
  # - `params`: A map with filter parameters defined in HTTP request.
  #
  # ## Returns
  # - A list with prepared filter parameters.
  @spec interop_extract_message_filters(map()) :: list()
  defp interop_extract_message_filters(params) do
    [
      nonce: interop_prepare_nonce_filter(params["interop_message_nonce"]),
      age: interop_prepare_age_filter(params["interop_message_age_from"], params["interop_message_age_to"]),
      statuses: interop_prepare_statuses_filter(params["interop_message_statuses"]),
      init_transaction_hash: interop_prepare_transaction_hash_filter(params["interop_message_init_transaction_hash"]),
      relay_transaction_hash: interop_prepare_transaction_hash_filter(params["interop_message_relay_transaction_hash"]),
      senders:
        interop_prepare_include_exclude_address_hashes_filter(
          params["interop_message_sender_address_hashes_to_include"],
          params["interop_message_sender_address_hashes_to_exclude"]
        ),
      targets:
        interop_prepare_include_exclude_address_hashes_filter(
          params["interop_message_target_address_hashes_to_include"],
          params["interop_message_target_address_hashes_to_exclude"]
        ),
      direction: interop_prepare_direction_filter(params["interop_message_direction"])
    ]
  end

  # Handles the `interop_message_nonce` parameter from HTTP request for the interop message list.
  # Converts the string with nonce to the integer.
  #
  # ## Parameters
  # - `nonce`: The nonce string.
  #
  # ## Returns
  # - The nonce integer in case the nonce string is correct.
  # - `nil` in case of invalid string.
  @spec interop_prepare_nonce_filter(String.t()) :: non_neg_integer() | nil
  defp interop_prepare_nonce_filter(nonce) when is_binary(nonce) do
    nonce
    |> String.trim()
    |> Integer.parse()
    |> case do
      {int_nonce, ""} -> int_nonce
      _ -> nil
    end
  end

  defp interop_prepare_nonce_filter(_), do: nil

  # Handles `interop_message_age_from` and `interop_message_age_to` parameters from HTTP request for the interop message list.
  # Converts the ISO 8601 strings to the corresponding `DateTime` typed values.
  #
  # ## Parameters
  # - `from`: The string with start datetime of the range.
  # - `to`: The string with end datetime of the range.
  #
  # ## Returns
  # - A list `[from: DateTime.t() | nil, to: DateTime.t() | nil]` with the converted values.
  #   The `from` or `to` component can be `nil` if the corresponding input has invalid datetime format.
  @spec interop_prepare_age_filter(String.t(), String.t()) :: list()
  defp interop_prepare_age_filter(from, to), do: [from: parse_date(from), to: parse_date(to)]

  # Converts ISO 8601 string to the corresponding `DateTime` typed value.
  #
  # ## Parameters
  # - `string_date`: The string with datetime in ISO 8601.
  #
  # ## Returns
  # - The converted datetime value.
  # - `nil` in case of invalid input.
  @spec parse_date(String.t()) :: DateTime.t() | nil
  defp parse_date(string_date) do
    case string_date && DateTime.from_iso8601(string_date) do
      {:ok, date, _utc_offset} -> date
      _ -> nil
    end
  end

  @allowed_interop_message_statuses ~w(SENT RELAYED FAILED)

  # Handles the `interop_message_statuses` parameter from HTTP request for the interop message list.
  # Converts the string with statuses to the statuses list.
  #
  # ## Parameters
  # - `statuses`: The string with comma-separated statuses, e.g.: `Sent,Relayed,Failed`.
  #
  # ## Returns
  # - The corresponding list with uppercased items, e.g.: ["SENT","RELAYED","FAILED"]
  # - An empty list if the input string is invalid.
  @spec interop_prepare_statuses_filter(String.t()) :: list()
  defp interop_prepare_statuses_filter(statuses) when is_binary(statuses) do
    statuses
    |> String.upcase()
    |> String.split(",")
    |> Enum.map(&String.trim(&1))
    |> Enum.filter(&(&1 in @allowed_interop_message_statuses))
  end

  defp interop_prepare_statuses_filter(_), do: []

  # Handles the `interop_message_init_transaction_hash` and `interop_message_relay_transaction_hash` parameters
  # from HTTP request for the interop message list. Converts the string with transaction hash to `Explorer.Chain.Hash.t()`.
  #
  # ## Parameters
  # - `transaction_hash`: The transaction hash string containing 64 symbols after `0x` prefix.
  #
  # ## Returns
  # - The transaction hash in case the input string is correct.
  # - `nil` in case of invalid string.
  @spec interop_prepare_transaction_hash_filter(String.t()) :: Hash.t() | nil
  defp interop_prepare_transaction_hash_filter(transaction_hash) when is_binary(transaction_hash) do
    transaction_hash
    |> String.trim()
    |> Chain.string_to_full_hash()
    |> case do
      {:ok, hash} -> hash
      _ -> nil
    end
  end

  defp interop_prepare_transaction_hash_filter(_), do: nil

  # Handles `interop_message_sender_address_hashes_to_include`, `interop_message_sender_address_hashes_to_exclude`,
  # `interop_message_target_address_hashes_to_include`, and `interop_message_target_address_hashes_to_exclude` parameters
  # from HTTP request for the interop message list. Converts the strings containing comma-separated addresses
  # to the input lists of `Hash.Address.t()` for `Explorer.Chain.Optimism.InteropMessage.list/1` function.
  # Each address must have 40 hexadecimal digits after the `0x` base prefix.
  #
  # ## Parameters
  # - `include`: accepts `interop_message_sender_address_hashes_to_include` or `interop_message_target_address_hashes_to_include` parameter value.
  # - `exclude`: accepts `interop_message_sender_address_hashes_to_exclude` or `interop_message_target_address_hashes_to_exclude` parameter value.
  #
  # ## Returns
  # - A list `[include: [Hash.Address.t()], exclude: [Hash.Address.t()]]` with the converted addresses.
  @spec interop_prepare_include_exclude_address_hashes_filter(String.t(), String.t()) :: [
          include: [Hash.Address.t()],
          exclude: [Hash.Address.t()]
        ]
  defp interop_prepare_include_exclude_address_hashes_filter(include, exclude) do
    [
      include: interop_prepare_address_hashes_filter(include),
      exclude: interop_prepare_address_hashes_filter(exclude)
    ]
  end

  # Converts the string containing comma-separated addresses to the list of `Hash.Address.t()`.
  # Each address must have 40 hexadecimal digits after the `0x` base prefix.
  #
  # ## Parameters
  # - `address_hashes`: The string with comma-separated addresses.
  #
  # ## Returns
  # - The corresponding list `[Hash.Address.t()]`. The list is empty if the input string is empty or all addresses
  #   are incorrect. Incorrect addresses are not included into the list.
  @spec interop_prepare_address_hashes_filter(String.t()) :: [Hash.Address.t()]
  defp interop_prepare_address_hashes_filter(address_hashes) when is_binary(address_hashes) do
    address_hashes
    |> String.split(",")
    |> Enum.map(&interop_prepare_address_hash_filter(&1))
    |> Enum.reject(&is_nil(&1))
  end

  defp interop_prepare_address_hashes_filter(_), do: nil

  # Converts an address hash string with `0x` prefix to `Hash.Address.t()`.
  # The address must have 40 hexadecimal digits after the `0x` base prefix.
  #
  # ## Parameters
  # - `address_hash`: The input string with address.
  #
  # ## Returns
  # - `Hash.Address.t()` in case of correct address.
  # - `nil` if the address is invalid.
  @spec interop_prepare_address_hash_filter(String.t()) :: Hash.Address.t() | nil
  defp interop_prepare_address_hash_filter(address_hash) do
    address_hash
    |> String.trim()
    |> Chain.string_to_address_hash_or_nil()
  end

  # Handles the `interop_message_direction` parameter from HTTP request for the interop message list.
  # Converts the string with the direction to the corresponding atom.
  #
  # ## Parameters
  # - `direction`: The direction string. Can be one of: "in", "out".
  #
  # ## Returns
  # - `:in` for the incoming direction.
  # - `:out` for the outgoing direction.
  # - `nil` for all directions.
  @spec interop_prepare_direction_filter(String.t() | nil) :: :in | :out | nil
  defp interop_prepare_direction_filter(direction) do
    case direction && String.downcase(direction) do
      "in" -> :in
      "out" -> :out
      _ -> nil
    end
  end

  # Renders HTTP error code and message.
  #
  # ## Parameters
  # - `conn`: The connection struct.
  # - `error_code`: The error code (e.g. 500 or :unauthorized).
  # - `error_message`: The error description.
  #
  # ## Returns
  # - The connection struct with the rendered response.
  @spec interop_render_http_error(Plug.Conn.t(), atom() | non_neg_integer(), String.t()) :: Plug.Conn.t()
  defp interop_render_http_error(conn, error_code, error_message) do
    Logger.error("Interop: #{error_message}")

    conn
    |> put_view(ApiView)
    |> put_status(error_code)
    |> render(:message, %{message: error_message})
  end

  # Fetches interop public key from the given instance using `/api/v2/optimism/interop/public-key` HTTP request to that instance.
  # The successful response is cached in memory until the current instance is down.
  #
  # Firstly, it tries to read the public key from cache. If that's not found in cache, the HTTP request is performed.
  #
  # ## Parameters
  # - `instance_api_url`: The instance API URL previously got by the `InteropMessage.interop_chain_id_to_instance_api_url` function.
  #                       Can be `nil` in case of failure.
  #
  # ## Returns
  # - Public key as binary byte sequence in case of success.
  # - `nil` in case of fail.
  @spec interop_fetch_public_key(String.t() | nil) :: binary() | nil
  defp interop_fetch_public_key(nil), do: nil

  defp interop_fetch_public_key(instance_api_url) do
    public_key = ConCache.get(InteropMessage.interop_instance_api_url_to_public_key_cache(), instance_api_url)

    if is_nil(public_key) do
      env = Application.get_all_env(:indexer)[InteropMessageQueue]
      url = instance_api_url <> "/api/v2/optimism/interop/public-key"

      timeout = :timer.seconds(env[:connect_timeout])
      recv_timeout = :timer.seconds(env[:recv_timeout])
      client = Tesla.client([{Tesla.Middleware.Timeout, timeout: recv_timeout}], Tesla.Adapter.Mint)

      with {:ok, %{body: response_body, status: 200}} <-
             Tesla.get(client, url, opts: [adapter: [timeout: recv_timeout, transport_opts: [timeout: timeout]]]),
           {:ok, %{"public_key" => "0x" <> key}} <- Jason.decode(response_body),
           {:ok, key_binary} <- Base.decode16(key, case: :mixed),
           true <- byte_size(key_binary) > 0 do
        ConCache.put(InteropMessage.interop_instance_api_url_to_public_key_cache(), instance_api_url, key_binary)
        key_binary
      else
        reason ->
          Logger.error("Interop: unable to get public key from #{url}. Reason: #{inspect(reason)}")
          nil
      end
    else
      public_key
    end
  end

  defp items_count(conn, module) do
    count = Chain.get_table_rows_total_count(module, api?: true)

    conn
    |> put_status(200)
    |> render(:optimism_items_count, %{count: count})
  end
end
