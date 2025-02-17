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

  alias BlockScoutWeb.API.V2.ApiView
  alias Explorer.Chain
  alias Explorer.Chain.Transaction

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

  alias Indexer.Fetcher.Optimism
  alias Indexer.Fetcher.Optimism.InteropMessageQueue

  action_fallback(BlockScoutWeb.API.V2.FallbackController)

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

    private_key = env[:private_key] |> String.trim_leading("0x") |> Base.decode16!(case: :mixed)

    case ExSecp256k1.create_public_key(private_key) do
      {:ok, public_key} ->
        conn
        |> put_status(200)
        |> render(:optimism_interop_public_key, %{public_key: "0x" <> Base.encode16(public_key, case: :lower)})

      _ ->
        Logger.error("Interop: cannot derive a public key from the private key. Private key is invalid or undefined.")

        conn
        |> put_status(:not_found)
        |> render(:message, %{message: "private key is invalid or undefined"})
    end
  end

  @doc """
    Function to handle POST request to `/api/v2/optimism/interop/import` endpoint.
    Accepts `init` part of the interop message from the source instance or
    `relay` part of the interop message from the target instance.
  """
  @spec interop_import(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def interop_import(
        conn,
        %{
          "sender" => sender,
          "target" => target,
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
      sender <>
        target <>
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

  @spec interop_import_internal(non_neg_integer(), String.t(), String.t(), map(), function(), Plug.Conn.t()) ::
          Plug.Conn.t()
  defp interop_import_internal(remote_chain_id, data_to_verify, signature, params, missed_part_fn, conn) do
    # we need to know the remote instance URL to get public key from that
    public_key =
      remote_chain_id
      |> interop_chain_id_to_instance_url()
      |> interop_fetch_public_key()

    with {:empty_public_key, false} <- {:empty_public_key, is_nil(public_key)},
         {:wrong_signature, false} <-
           {:wrong_signature,
            ExSecp256k1.verify(data_to_verify, Base.decode16!(signature, case: :mixed), public_key) != :ok},
         # the data is verified, so now we can import that to the database
         {:ok, _} <-
           Chain.import(%{optimism_interop_messages: %{params: [interop_prepare_import(params)]}, timeout: :infinity}) do
      conn
      |> put_view(ApiView)
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

  defp interop_prepare_import(%{"init_transaction_hash" => init_transaction_hash} = params) do
    %{
      sender: params["sender"],
      target: params["target"],
      nonce: params["nonce"],
      init_chain_id: params["init_chain_id"],
      init_transaction_hash: init_transaction_hash,
      timestamp: DateTime.from_unix!(params["timestamp"]),
      relay_chain_id: params["relay_chain_id"],
      payload: params["payload"] |> String.trim_leading("0x") |> Base.decode16!(case: :mixed)
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

  defp interop_render_http_error(conn, error_code, error_message) do
    Logger.error("Interop: #{error_message}")

    conn
    |> put_view(ApiView)
    |> put_status(error_code)
    |> render(:message, %{message: error_message})
  end

  defp interop_chain_id_to_instance_url(chain_id) do
    env = Application.get_all_env(:indexer)[InteropMessageQueue]

    case Map.get(env[:chainscout_fallback_map], chain_id) do
      nil -> Optimism.get_instance_url_by_chain_id(chain_id, env[:chainscout_api_url])
      url -> String.trim_trailing(url, "/")
    end
  end

  defp interop_fetch_public_key(instance_url) do
    url = instance_url <> "/api/v2/optimism/interop/public-key"

    with {:ok, %HTTPoison.Response{body: "0x" <> key, status_code: 200}} <- HTTPoison.get(url),
         {:ok, key_binary} <- Base.decode16(key, case: :mixed),
         true <- byte_size(key_binary) > 0 do
      key_binary
    else
      _ ->
        Logger.error("Interop: unable to get public key from #{url}")
        nil
    end
  end

  defp items_count(conn, module) do
    count = Chain.get_table_rows_total_count(module, api?: true)

    conn
    |> put_status(200)
    |> render(:optimism_items_count, %{count: count})
  end
end
