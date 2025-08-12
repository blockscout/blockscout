defmodule Indexer.Fetcher.Optimism.Interop.MessageQueue do
  @moduledoc """
    Searches for incomplete messages in the `op_interop_messages` database table and sends message's data to the
    remote instance through API post request to fill missed part and notify the remote side about the known part.
    An incomplete message is the message for which an init transaction or relay transaction is unknown yet.
    The number of incomplete messages considered depends on INDEXER_OPTIMISM_INTEROP_EXPORT_EXPIRATION_DAYS env variable.

    The data being sent is signed with a private key defined in INDEXER_OPTIMISM_INTEROP_PRIVATE_KEY env variable.

    The module constructs correct API URL to send the data to based on the chain ID. A `chain_id -> instance_url` map
    is available in Chainscout API (which URL is defined in INDEXER_OPTIMISM_CHAINSCOUT_API_URL env variable) or
    can be defined with INDEXER_OPTIMISM_CHAINSCOUT_FALLBACK_MAP env variable in form of JSON object, e.g.:

    {"10":"https://optimism.blockscout.com/","8453":"https://base.blockscout.com/"}

    or extended case (when API and UI have different URLs):

    {"123" : {"api" : "http://localhost:4000/", "ui" : "http://localhost:3000/"}, "456" : {"api" : "http://localhost:4100/", "ui" : "http://localhost:3100/"}}

    In production chains INDEXER_OPTIMISM_CHAINSCOUT_API_URL env should be defined as `https://chains.blockscout.com/api/chains/`.
    In local dev chains INDEXER_OPTIMISM_CHAINSCOUT_API_URL env should be omitted as the Chainscout doesn't have any info about
    some dev chain. For local dev case INDEXER_OPTIMISM_CHAINSCOUT_FALLBACK_MAP must be used.
  """

  use GenServer
  use Indexer.Fetcher

  require Logger

  import Explorer.Helper, only: [hash_to_binary: 1]
  import Indexer.Fetcher.Optimism.Interop.Helper, only: [log_cant_get_chain_id_from_rpc: 0]

  alias Explorer.Chain
  alias Explorer.Chain.Cache.Counters.LastFetchedCounter
  alias Explorer.Chain.{Data, Hash}
  alias Explorer.Chain.Optimism.InteropMessage
  alias Indexer.Fetcher.Optimism
  alias Indexer.Helper

  @counter_type "optimism_interop_messages_queue_iteration"
  @fetcher_name :optimism_interop_messages_queue
  @api_endpoint_import "/api/v2/import/optimism/interop/"
  @chunk_size 1000

  def child_spec(start_link_arguments) do
    spec = %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, start_link_arguments},
      restart: :transient,
      type: :worker
    }

    Supervisor.child_spec(spec, [])
  end

  def start_link(args, gen_server_options \\ []) do
    GenServer.start_link(__MODULE__, args, Keyword.put_new(gen_server_options, :name, __MODULE__))
  end

  @impl GenServer
  def init(args) do
    {:ok, %{}, {:continue, args[:json_rpc_named_arguments]}}
  end

  # Initialization function which is used instead of `init` to avoid Supervisor's stop in case of any critical issues
  # during initialization. It checks the value of INDEXER_OPTIMISM_CHAINSCOUT_API_URL, INDEXER_OPTIMISM_CHAINSCOUT_FALLBACK_MAP,
  # and INDEXER_OPTIMISM_INTEROP_PRIVATE_KEY env variables and starts the handling loop.
  #
  # Also, the function fetches the current chain id to use it in the handler.
  #
  # When the initialization succeeds, the `:continue` message is sent to GenServer to start the queue handler loop.
  #
  # ## Parameters
  # - `json_rpc_named_arguments`: Configuration parameters for the JSON RPC connection to RPC node.
  # - `_state`: Initial state of the fetcher (empty map when starting).
  #
  # ## Returns
  # - `{:noreply, state}` when the initialization is successful and the handling can start. The `state` contains
  #                       necessary parameters needed for the handling.
  # - `{:stop, :normal, %{}}` in case of error or when both env variables are not defined.
  @impl GenServer
  @spec handle_continue(EthereumJSONRPC.json_rpc_named_arguments(), map()) ::
          {:noreply, map()} | {:stop, :normal, map()}
  def handle_continue(json_rpc_named_arguments, _state) do
    Logger.metadata(fetcher: @fetcher_name)

    # two seconds pause needed to avoid exceeding Supervisor restart intensity when DB issues
    :timer.sleep(2000)

    env = Application.get_all_env(:indexer)[__MODULE__]

    with false <- is_nil(env[:chainscout_api_url]) and env[:chainscout_fallback_map] == %{},
         {:ok, _} <- ExSecp256k1.create_public_key(hash_to_binary(env[:private_key])),
         chain_id = Optimism.fetch_chain_id(),
         {:chain_id_is_nil, false} <- {:chain_id_is_nil, is_nil(chain_id)},
         block_duration = Application.get_env(:indexer, Indexer.Fetcher.Optimism)[:block_duration],
         {:block_duration_is_invalid, false} <-
           {:block_duration_is_invalid, not is_integer(block_duration) or block_duration <= 0} do
      chainscout_map =
        env[:chainscout_fallback_map]
        |> Enum.map(fn {id, url} ->
          {String.to_integer(id), String.trim_trailing(if(is_map(url), do: url["api"], else: url), "/")}
        end)
        |> Enum.into(%{})

      Process.send(self(), :continue, [])

      {:noreply,
       %{
         chain_id: chain_id,
         chainscout_api_url: env[:chainscout_api_url],
         chainscout_map: chainscout_map,
         timeout: :timer.seconds(env[:connect_timeout]),
         recv_timeout: :timer.seconds(env[:recv_timeout]),
         export_expiration_blocks: div(env[:export_expiration] * 24 * 3600, block_duration),
         iterations_done: Decimal.to_integer(LastFetchedCounter.get(@counter_type)),
         json_rpc_named_arguments: json_rpc_named_arguments
       }}
    else
      true ->
        # Chainscout API URL and fallback map are not defined, so we don't start this module
        Logger.warning(
          "Both INDEXER_OPTIMISM_CHAINSCOUT_API_URL and INDEXER_OPTIMISM_CHAINSCOUT_FALLBACK_MAP are not defined. The module #{__MODULE__} will not start."
        )

        {:stop, :normal, %{}}

      {:chain_id_is_nil, true} ->
        log_cant_get_chain_id_from_rpc()
        {:stop, :normal, %{}}

      {:block_duration_is_invalid, true} ->
        Logger.error("Please, check INDEXER_OPTIMISM_BLOCK_DURATION env variable. It is invalid or undefined.")
        {:stop, :normal, %{}}

      _ ->
        Logger.error(
          "Private key is invalid or undefined. Please, check INDEXER_OPTIMISM_INTEROP_PRIVATE_KEY env variable."
        )

        {:stop, :normal, %{}}
    end
  end

  # Performs the main handling loop searching for incomplete messages.
  #
  # Details of each incomplete message are prepared, signed, and sent to the remote instance through its API.
  # The remote instance response for the message is used to import missed message's data to the database on the
  # current instance, so an incomplete message becomes complete.
  #
  # ## Parameters
  # - `:continue`: The GenServer message.
  # - `state`: The current state of the fetcher containing the current chain ID, Chainscout map and API URL,
  #            a private key for signing details, and HTTP timeouts.
  #
  # ## Returns
  # - `{:noreply, state}` tuple where `state` is the new state of the fetcher which can have updated Chainscout map.
  @impl GenServer
  def handle_info(
        :continue,
        %{
          chain_id: current_chain_id,
          chainscout_api_url: chainscout_api_url,
          chainscout_map: chainscout_map,
          timeout: timeout,
          recv_timeout: recv_timeout,
          export_expiration_blocks: export_expiration_blocks,
          iterations_done: iterations_done,
          json_rpc_named_arguments: json_rpc_named_arguments
        } = state
      ) do
    private_key = hash_to_binary(Application.get_all_env(:indexer)[__MODULE__][:private_key])

    LastFetchedCounter.upsert(%{
      counter_type: @counter_type,
      value: iterations_done
    })

    # the first three iterations scan all incomplete messages,
    # but subsequent scans are limited by INDEXER_OPTIMISM_INTEROP_EXPORT_EXPIRATION_DAYS env
    start_block_number =
      if iterations_done < 3 do
        0
      else
        {:ok, latest_block_number} =
          Helper.get_block_number_by_tag("latest", json_rpc_named_arguments, Helper.infinite_retries_number())

        max(latest_block_number - export_expiration_blocks, 0)
      end

    %{min: min_block_number, max: max_block_number, count: message_count} =
      InteropMessage.get_incomplete_messages_stats(current_chain_id, start_block_number)

    chunks_number = ceil(message_count / @chunk_size)
    chunk_range = Range.new(0, max(chunks_number - 1, 0), 1)

    updated_chainscout_map =
      chunk_range
      |> Enum.reduce(chainscout_map, fn current_chunk, chainscout_map_acc ->
        current_chain_id
        |> InteropMessage.get_incomplete_messages(
          min_block_number,
          max_block_number,
          @chunk_size,
          current_chunk * @chunk_size
        )
        |> Enum.reduce(chainscout_map_acc, fn message, chainscout_map_acc_internal ->
          {instance_chain_id, post_data_signed} = prepare_post_data(message, private_key)

          url_from_map = Map.get(chainscout_map_acc_internal, instance_chain_id)

          instance_url =
            with {:url_from_map_is_nil, true, _} <- {:url_from_map_is_nil, is_nil(url_from_map), url_from_map},
                 info = InteropMessage.get_instance_info_by_chain_id(instance_chain_id, chainscout_api_url),
                 {:url_from_chainscout_avail, true} <- {:url_from_chainscout_avail, not is_nil(info)} do
              info.instance_url
            else
              {:url_from_map_is_nil, false, url_from_map} ->
                url_from_map

              {:url_from_chainscout_avail, false} ->
                nil
            end

          with false <- is_nil(instance_url),
               endpoint_url = instance_url <> @api_endpoint_import,
               response = post_json_request(endpoint_url, post_data_signed, timeout, recv_timeout),
               false <- is_nil(response) do
            {:ok, _} =
              Chain.import(%{
                optimism_interop_messages: %{params: [prepare_import(message, response)]},
                timeout: :infinity
              })

            Logger.info(
              "Message details successfully sent to #{endpoint_url}. Request body: #{inspect(post_data_signed)}. Response body: #{inspect(response)}"
            )
          end

          # credo:disable-for-next-line Credo.Check.Refactor.Nesting
          if is_nil(instance_url) do
            chainscout_map_acc_internal
          else
            Map.put(chainscout_map_acc_internal, instance_chain_id, instance_url)
          end
        end)
      end)

    Process.send_after(self(), :continue, :timer.seconds(3))

    {:noreply, %{state | chainscout_map: updated_chainscout_map, iterations_done: iterations_done + 1}}
  end

  @impl GenServer
  def handle_info({ref, _result}, state) do
    Process.demonitor(ref, [:flush])
    {:noreply, state}
  end

  # Prepares data to send as POST request to the remote API endpoint.
  #
  # ## Parameters
  # - `message`: A map containing the existing message data.
  # - `private_key`: A private key to sign the data with.
  #
  # ## Returns
  # - `{instance_chain_id, post_data_signed}` tuple where
  #   `instance_chain_id` is the chain id of the remote instance,
  #   `post_data_signed` is the data map with the `signature` field.
  @spec prepare_post_data(map(), binary()) :: {non_neg_integer(), map()}
  defp prepare_post_data(message, private_key) when is_nil(message.relay_transaction_hash) do
    timestamp = DateTime.to_unix(message.timestamp)

    data = %{
      sender_address_hash: Hash.to_string(message.sender_address_hash),
      target_address_hash: Hash.to_string(message.target_address_hash),
      nonce: message.nonce,
      init_chain_id: message.init_chain_id,
      init_transaction_hash: Hash.to_string(message.init_transaction_hash),
      timestamp: timestamp,
      relay_chain_id: message.relay_chain_id,
      payload: message.payload,
      signature: nil
    }

    data_to_sign =
      data.sender_address_hash <>
        data.target_address_hash <>
        Integer.to_string(message.nonce) <>
        Integer.to_string(message.init_chain_id) <>
        data.init_transaction_hash <>
        Integer.to_string(timestamp) <> Integer.to_string(message.relay_chain_id) <> to_string(message.payload)

    {:ok, {signature, _}} =
      data_to_sign
      |> ExKeccak.hash_256()
      |> ExSecp256k1.sign_compact(private_key)

    set_post_data_signature(message.relay_chain_id, data, signature)
  end

  defp prepare_post_data(message, private_key) do
    data = %{
      nonce: message.nonce,
      init_chain_id: message.init_chain_id,
      relay_chain_id: message.relay_chain_id,
      relay_transaction_hash: Hash.to_string(message.relay_transaction_hash),
      failed: message.failed,
      signature: nil
    }

    data_to_sign =
      Integer.to_string(message.nonce) <>
        Integer.to_string(message.init_chain_id) <>
        Integer.to_string(message.relay_chain_id) <> data.relay_transaction_hash <> to_string(message.failed)

    {:ok, {signature, _}} =
      data_to_sign
      |> ExKeccak.hash_256()
      |> ExSecp256k1.sign_compact(private_key)

    set_post_data_signature(message.init_chain_id, data, signature)
  end

  # Adds signature to the data sent as POST request to the remote API endpoint.
  #
  # ## Parameters
  # - `chain_id`: An integer defining the chain ID.
  # - `data`: The given data to set the `signature` field for.
  # - `signature`: The signature to set.
  #
  # ## Returns
  # - `{chain_id, post_data_signed}` tuple where
  #   `chain_id` is the chain id from the input parameter.
  #   `post_data_signed` is the `data` map with the `signature` field.
  @doc false
  @spec set_post_data_signature(non_neg_integer(), map(), binary()) :: {non_neg_integer(), map()}
  def set_post_data_signature(chain_id, data, signature) do
    {chain_id, %{data | signature: %Data{bytes: signature} |> to_string()}}
  end

  # Prepares a map to import to the `op_interop_messages` table based on the current handling message and
  # the response from the remote instance.
  #
  # ## Parameters
  # - `message`: A map containing the existing message data.
  # - `response`: A map containing the response from the remote instance.
  #
  # ## Returns
  # - A map containing the missed message's data received from the remote instance. The map structure depends on
  #   the message direction (incoming or outgoing).
  @spec prepare_import(map(), map()) :: map()
  defp prepare_import(message, response) do
    if is_nil(message.relay_transaction_hash) do
      # this is outgoing message without relay part, so we sent message details to the target instance
      # and got relay details from the target instance
      %{
        nonce: message.nonce,
        init_chain_id: message.init_chain_id,
        relay_chain_id: message.relay_chain_id,
        relay_transaction_hash: Map.get(response, "relay_transaction_hash"),
        failed: Map.get(response, "failed")
      }
    else
      # this is incoming message without init part, so we sent relay details to the source instance
      # and got message details from the source instance
      timestamp =
        case Map.get(response, "timestamp") do
          nil -> nil
          ts -> DateTime.from_unix!(ts)
        end

      payload =
        case Map.get(response, "payload") do
          nil -> nil
          pl -> hash_to_binary(pl)
        end

      [transfer_token_address_hash, transfer_from_address_hash, transfer_to_address_hash, transfer_amount] =
        InteropMessage.decode_payload(payload)

      %{
        sender_address_hash: Map.get(response, "sender_address_hash"),
        target_address_hash: Map.get(response, "target_address_hash"),
        nonce: message.nonce,
        init_chain_id: message.init_chain_id,
        init_transaction_hash: Map.get(response, "init_transaction_hash"),
        relay_chain_id: message.relay_chain_id,
        timestamp: timestamp,
        payload: payload,
        transfer_token_address_hash: transfer_token_address_hash,
        transfer_from_address_hash: transfer_from_address_hash,
        transfer_to_address_hash: transfer_to_address_hash,
        transfer_amount: transfer_amount
      }
    end
  end

  # Sends message's data to the given remote instance using HTTP POST request and returns a response from the instance.
  #
  # ## Parameters
  # - `url`: URL of the remote API endpoint to send the data to.
  # - `body`: A map with message's data.
  # - `timeout`: Connect timeout, in milliseconds.
  # - `recv_timeout`: timeout for receiving an HTTP response from the socket, in milliseconds.
  #
  # ## Returns
  # - A response map in case of success.
  # - `nil` in case of failure (failed HTTP request or invalid JSON response).
  @spec post_json_request(String.t(), map(), non_neg_integer(), non_neg_integer()) :: map() | nil
  defp post_json_request(url, body, timeout, recv_timeout) do
    client = Tesla.client([{Tesla.Middleware.Timeout, timeout: recv_timeout}], Tesla.Adapter.Mint)
    headers = [{"Content-Type", "application/json"}]
    opts = [adapter: [timeout: recv_timeout, transport_opts: [timeout: timeout]]]

    case Tesla.post(client, url, Jason.encode!(body), headers: headers, opts: opts) do
      {:ok, %{body: response_body, status: 200}} ->
        case Jason.decode(response_body) do
          {:ok, response} ->
            response

          _ ->
            Logger.error(
              "Cannot decode response from #{url}. Response body: #{inspect(response_body)}. Request body: #{body}"
            )

            nil
        end

      other ->
        Logger.error("Cannot post HTTP request to #{url}. Reason: #{inspect(other)}. Body: #{inspect(body)}")
        nil
    end
  end
end
