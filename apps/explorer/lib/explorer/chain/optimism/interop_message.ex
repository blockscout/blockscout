defmodule Explorer.Chain.Optimism.InteropMessage do
  @moduledoc "Models interop message for Optimism."

  use Explorer.Schema

  require Logger

  import Explorer.Chain, only: [default_paging_options: 0, select_repo: 1]

  alias Explorer.Chain.Hash
  alias Explorer.{PagingOptions, Repo}
  alias Indexer.Fetcher.Optimism.InteropMessageQueue

  @required_attrs ~w(nonce init_chain_id relay_chain_id)a
  @optional_attrs ~w(sender target init_transaction_hash block_number timestamp relay_transaction_hash payload failed)a
  @interop_chain_id_to_instance_info_cache :interop_chain_id_to_instance_info_cache

  @typedoc """
    * `sender` - An address of the sender on the source chain. Can be a smart contract. Can be `nil` (when SentMessage event is not indexed yet).
    * `target` - A target address on the target chain. Can be a smart contract. Can be `nil` (when SentMessage event is not indexed yet).
    * `nonce` - Nonce associated with the message sent. Unique within the source chain.
    * `init_chain_id` - Chain ID of the source chain.
    * `init_transaction_hash` - Transaction hash (on the source chain) associated with the message sent. Can be `nil` (when SentMessage event is not indexed yet).
    * `block_number` - Block number of the `init_transaction_hash` for outgoing message. Block number of the `relay_transaction_hash` for incoming message.
    * `timestamp` - Timestamp of the `init_transaction_hash` transaction. Can be `nil` (when SentMessage event is not indexed yet).
    * `relay_chain_id` - Chain ID of the target chain.
    * `relay_transaction_hash` - Transaction hash (on the target chain) associated with the message relay transaction. Can be `nil` (when relay transaction is not indexed yet).
    * `payload` - Message payload to call target with. Can be `nil` (when SentMessage event is not indexed yet).
    * `failed` - Fail status of the relay transaction. Can be `nil` (when relay transaction is not indexed yet).
  """
  @primary_key false
  typed_schema "op_interop_messages" do
    field(:sender, Hash.Address)
    field(:target, Hash.Address)
    field(:nonce, :integer, primary_key: true)
    field(:init_chain_id, :integer, primary_key: true)
    field(:init_transaction_hash, Hash.Full)
    field(:block_number, :integer)
    field(:timestamp, :utc_datetime_usec)
    field(:relay_chain_id, :integer)
    field(:relay_transaction_hash, Hash.Full)
    field(:payload, :binary)
    field(:failed, :boolean)

    timestamps()
  end

  @doc """
    Validates that the attributes are valid.
  """
  def changeset(%__MODULE__{} = message, attrs \\ %{}) do
    message
    |> cast(attrs, @required_attrs ++ @optional_attrs)
    |> validate_required(@required_attrs)
  end

  @doc """
    Removes rows from the `op_interop_messages` table which have a block number
    greater than the latest block number. They could be created due to reorg.

    ## Parameters
    - `latest_block_number`: The latest block number.

    ## Returns
    - A number of removed rows.
  """
  @spec remove_invalid_messages(integer()) :: non_neg_integer()
  def remove_invalid_messages(latest_block_number) do
    {deleted_count, _} =
      Repo.delete_all(from(m in __MODULE__, where: m.block_number > ^latest_block_number), timeout: :infinity)

    deleted_count
  end

  @doc """
    Reads the last row from the `op_interop_messages` table.

    ## Parameters
    - `current_chain_id`: The current chain ID.
    - `only_failed`: True if only failed relay transactions are taken into account.

    ## Returns
    - `{block_number, transaction_hash}` tuple for the last row.
    - `{0, nil}` if there are no rows in the table.
  """
  @spec get_last_item(non_neg_integer(), boolean()) :: {non_neg_integer(), binary() | nil}
  def get_last_item(current_chain_id, only_failed) do
    base_query =
      from(m in __MODULE__,
        select: {m.block_number, m.init_chain_id, m.init_transaction_hash, m.relay_chain_id, m.relay_transaction_hash},
        where: not is_nil(m.block_number),
        order_by: [desc: m.block_number],
        limit: 1
      )

    query =
      if only_failed do
        where(base_query, [m], m.failed == true)
      else
        base_query
      end

    message =
      query
      |> Repo.one()

    if is_nil(message) do
      {0, nil}
    else
      {block_number, init_chain_id, init_transaction_hash, relay_chain_id, relay_transaction_hash} = message

      cond do
        current_chain_id == init_chain_id ->
          {block_number, init_transaction_hash}

        current_chain_id == relay_chain_id ->
          {block_number, relay_transaction_hash}

        true ->
          {0, nil}
      end
    end
  end

  @doc """
    Returns a list of incomplete messages from the `op_interop_messages` table.
    An incomplete message is the message for which an init transaction or relay transaction is unknown.

    ## Parameters
    - `current_chain_id`: The current chain ID to make correct query to the database.

    ## Returns
    - A list of the incomplete messages. Returns an empty list if they are not found.
  """
  @spec get_incomplete_messages(non_neg_integer()) :: list()
  def get_incomplete_messages(current_chain_id) do
    Repo.all(
      from(m in __MODULE__,
        where:
          (is_nil(m.relay_transaction_hash) and m.init_chain_id == ^current_chain_id) or
            (is_nil(m.init_transaction_hash) and m.relay_chain_id == ^current_chain_id)
      )
    )
  end

  @doc """
    Returns relay transaction hash and failure status from the `op_interop_messages` table for the given
    `init_chain_id` and `nonce`.

    ## Parameters
    - `init_chain_id`: The init chain ID of the message.
    - `nonce`: The nonce of the message.

    ## Returns
    - `{relay_transaction_hash, failed}` tuple in case of success.
    - `{nil, nil}` tuple if the message with the given `init_chain_id` and `nonce` is not found.
  """
  @spec get_relay_part(non_neg_integer(), non_neg_integer()) :: {Hash.t() | nil, boolean() | nil}
  def get_relay_part(init_chain_id, nonce) do
    query =
      from(m in __MODULE__,
        select: {m.relay_transaction_hash, m.failed},
        where: m.init_chain_id == ^init_chain_id and m.nonce == ^nonce
      )

    query
    |> Repo.one()
    |> Kernel.||({nil, nil})
  end

  @doc """
    Returns sender and target address, init transaction hash, timestamp, and payload from the `op_interop_messages` table
    for the given `init_chain_id` and `nonce`.

    ## Parameters
    - `init_chain_id`: The init chain ID of the message.
    - `nonce`: The nonce of the message.

    ## Returns
    - `{sender, target, init_transaction_hash, timestamp, payload}` tuple in case of success.
    - `{nil, nil, nil, nil, nil}` tuple if the message with the given `init_chain_id` and `nonce` is not found.
  """
  @spec get_init_part(non_neg_integer(), non_neg_integer()) ::
          {Hash.t() | nil, Hash.t() | nil, Hash.t() | nil, DateTime.t() | nil, binary() | nil}
  def get_init_part(init_chain_id, nonce) do
    query =
      from(m in __MODULE__,
        select: {m.sender, m.target, m.init_transaction_hash, m.timestamp, m.payload},
        where: m.init_chain_id == ^init_chain_id and m.nonce == ^nonce
      )

    query
    |> Repo.one()
    |> Kernel.||({nil, nil, nil, nil, nil})
  end

  @doc """
    Lists `t:Explorer.Chain.Optimism.InteropMessage.t/0`'s' in descending order based on `timestamp` and `init_transaction_hash`.

    ## Parameters
    - `options`: A keyword list of options that may include whether to use a replica database and paging options.

    ## Returns
    - A list of messages.
  """
  @spec list(list()) :: [__MODULE__.t()]
  def list(options \\ []) do
    paging_options = Keyword.get(options, :paging_options, default_paging_options())

    case paging_options do
      %PagingOptions{key: {0, _init_transaction_hash}} ->
        []

      _ ->
        base_query =
          from(m in __MODULE__,
            where: not is_nil(m.init_transaction_hash),
            order_by: [desc: m.timestamp, desc: m.init_transaction_hash]
          )

        base_query
        |> page_messages(paging_options)
        |> limit(^paging_options.page_size)
        |> select_repo(options).all(timeout: :infinity)
    end
  end

  @doc """
    Calculates the number of messages that can be displayed on the frontend side.

    ## Parameters
    - `options`: A keyword list of options that may include whether to use a replica database.

    ## Returns
    - The number of messages.
  """
  @spec count(list()) :: non_neg_integer()
  def count(options \\ []) do
    query =
      from(
        m in __MODULE__,
        where: not is_nil(m.init_transaction_hash)
      )

    select_repo(options).aggregate(query, :count, timeout: :infinity)
  end

  defp page_messages(query, %PagingOptions{key: nil}), do: query

  defp page_messages(query, %PagingOptions{key: {timestamp, init_transaction_hash}}) do
    from(m in query,
      where: m.timestamp < ^timestamp,
      or_where: m.timestamp == ^timestamp and m.init_transaction_hash < ^init_transaction_hash
    )
  end

  @doc """
    Extends interop message map with :status field.

    ## Parameters
    - `message`: The map with message info.

    ## Returns
    - Extended map.
  """
  @spec extend_with_status(map() | nil) :: map() | nil
  def extend_with_status(nil), do: nil

  def extend_with_status(message) do
    status =
      cond do
        is_nil(message.relay_transaction_hash) -> "Sent"
        message.failed -> "Failed"
        true -> "Relayed"
      end

    Map.put(message, :status, status)
  end

  @doc """
    Finds a message by transaction hash and prepares to display the message details on transaction page.
    Used by `BlockScoutWeb.API.V2.OptimismView.add_optimism_fields` function.

    ## Parameters
    - `transaction_hash`: The transaction hash we need to find the corresponding message for.

    ## Returns
    - A map with message details ready to be displayed on transaction page.
    - `nil` if the message not found.
  """
  @spec message_by_transaction(Hash.t()) :: map() | nil
  def message_by_transaction(transaction_hash) do
    query =
      from(
        m in __MODULE__,
        where: m.init_transaction_hash == ^transaction_hash or m.relay_transaction_hash == ^transaction_hash
      )

    message =
      query
      |> Repo.replica().one()
      |> extend_with_status()

    if not is_nil(message) do
      payload =
        if not is_nil(message.payload) do
          "0x" <> Base.encode16(message.payload, case: :lower)
        end

      chain_info =
        if message.init_transaction_hash == transaction_hash do
          %{
            "relay_chain" => interop_chain_id_to_instance_info(message.relay_chain_id),
            "relay_transaction_hash" => message.relay_transaction_hash
          }
        else
          %{
            "init_chain" => interop_chain_id_to_instance_info(message.init_chain_id),
            "init_transaction_hash" => message.init_transaction_hash
          }
        end

      Map.merge(
        %{
          "nonce" => message.nonce,
          "status" => message.status,
          "sender" => message.sender,
          "target" => message.target,
          "payload" => payload
        },
        chain_info
      )
    end
  end

  @doc """
    Sends HTTP request to Chainscout API to get instance info by its chain ID.

    ## Parameters
    - `chain_id`: The chain ID for which the instance info should be retrieved. Can be defined as String or Integer.
    - `chainscout_api_url`: URL defined in INDEXER_OPTIMISM_CHAINSCOUT_API_URL env variable. If `nil`, the function returns `nil`.

    ## Returns
    - A map with instance info (instance_url, chain_id, chain_name, chain_logo) in case of success.
    - `nil` in case of failure.
  """
  @spec get_instance_info_by_chain_id(String.t() | non_neg_integer(), String.t() | nil) :: map() | nil
  def get_instance_info_by_chain_id(chain_id, nil) do
    Logger.error(
      "Unknown instance URL for chain ID #{chain_id}. Please, define that in INDEXER_OPTIMISM_CHAINSCOUT_FALLBACK_MAP or define INDEXER_OPTIMISM_CHAINSCOUT_API_URL."
    )

    nil
  end

  def get_instance_info_by_chain_id(chain_id, chainscout_api_url) do
    url =
      if is_integer(chain_id) do
        chainscout_api_url <> Integer.to_string(chain_id)
      else
        chainscout_api_url <> chain_id
      end

    with {:ok, %HTTPoison.Response{body: body, status_code: 200}} <- HTTPoison.get(url),
         {:ok, response} <- Jason.decode(body),
         explorer = response |> Map.get("explorers", []) |> Enum.at(0),
         false <- is_nil(explorer),
         explorer_url = Map.get(explorer, "url"),
         false <- is_nil(explorer_url) do
      %{
        instance_url: String.trim_trailing(explorer_url, "/"),
        chain_id: chain_id,
        chain_name: Map.get(response, "name"),
        chain_logo: Map.get(response, "logo")
      }
    else
      true ->
        Logger.error("Cannot get explorer URL from #{url}")
        nil

      other ->
        Logger.error("Cannot get HTTP response from #{url}. Reason: #{inspect(other)}")
        nil
    end
  end

  @doc """
    Fetches instance URL by chain ID using a request to Chainscout API which URL is defined in INDEXER_OPTIMISM_CHAINSCOUT_API_URL env variable.
    The successful response is cached in memory until the current instance is down.

    Firstly, it tries to read the instance URL from INDEXER_OPTIMISM_CHAINSCOUT_FALLBACK_MAP env variable. If that's not defined, it tries to get
    the url from cache. If that's not found in cache, the HTTP request to Chainscout API is performed.

    ## Parameters
    - `chain_id`: The chain ID for which the instance URL needs to be retrieved.

    ## Returns
    - Instance URL if found (without trailing `/`).
    - `nil` if not found.
  """
  @spec interop_chain_id_to_instance_url(non_neg_integer()) :: String.t() | nil
  def interop_chain_id_to_instance_url(chain_id) do
    env = Application.get_all_env(:indexer)[InteropMessageQueue]
    url_from_map = Map.get(env[:chainscout_fallback_map], chain_id)

    with {:not_in_map, true} <- {:not_in_map, is_nil(url_from_map)},
         info_from_cache = ConCache.get(@interop_chain_id_to_instance_info_cache, chain_id),
         {:not_in_cache, true, _} <- {:not_in_cache, is_nil(info_from_cache), info_from_cache} do
      case get_instance_info_by_chain_id(chain_id, env[:chainscout_api_url]) do
        nil ->
          nil

        info ->
          ConCache.put(@interop_chain_id_to_instance_info_cache, chain_id, info)
          info.instance_url
      end
    else
      {:not_in_map, false} ->
        String.trim_trailing(url_from_map, "/")

      {:not_in_cache, false, info_from_cache} ->
        info_from_cache.instance_url
    end
  end

  @doc """
    Fetches instance info by chain ID using a request to Chainscout API which URL is defined in INDEXER_OPTIMISM_CHAINSCOUT_API_URL env variable.
    The successful response is cached in memory until the current instance is down.

    Firstly, it tries to read the instance info from cache. If that's not found in cache, the HTTP request to Chainscout API is performed.
    If the request fails, it tries to take the instance URL from INDEXER_OPTIMISM_CHAINSCOUT_FALLBACK_MAP (but chain name and logo left unknown).

    ## Parameters
    - `chain_id`: The chain ID for which the instance info needs to be retrieved.

    ## Returns
    - Instance info map if found.
    - `nil` if not found.
  """
  @spec interop_chain_id_to_instance_info(non_neg_integer()) :: map() | nil
  def interop_chain_id_to_instance_info(chain_id) do
    info_from_cache = ConCache.get(@interop_chain_id_to_instance_info_cache, chain_id)

    with {:not_in_cache, true, _} <- {:not_in_cache, is_nil(info_from_cache), info_from_cache},
         env = Application.get_all_env(:indexer)[InteropMessageQueue],
         info_from_chainscout = get_instance_info_by_chain_id(chain_id, env[:chainscout_api_url]),
         {:not_in_chainscout, true, _} <- {:not_in_chainscout, is_nil(info_from_chainscout), info_from_chainscout},
         url_from_map = Map.get(env[:chainscout_fallback_map], chain_id),
         {:in_fallback, true} <- {:in_fallback, not is_nil(url_from_map)} do
      info =
        %{
          instance_url: url_from_map,
          chain_id: chain_id,
          chain_name: nil,
          chain_logo: nil
        }

      ConCache.put(@interop_chain_id_to_instance_info_cache, chain_id, info)
      info
    else
      {:not_in_cache, false, info_from_cache} ->
        info_from_cache

      {:not_in_chainscout, false, info_from_chainscout} ->
        ConCache.put(@interop_chain_id_to_instance_info_cache, chain_id, info_from_chainscout)
        info_from_chainscout

      {:in_fallback, false} ->
        nil
    end
  end
end
