defmodule Indexer.Fetcher.Optimism.InteropMessageQueue do
  @moduledoc """
    Searches for incomplete messages in the `op_interop_messages` database table and sends message's data to the
    remote instance through API post request to fill missed part and notify the remote side about the known part.
    An incomplete message is the message for which an init transaction or relay transaction is unknown yet.

    The data being sent is signed with a private key defined in INDEXER_OPTIMISM_INTEROP_PRIVATE_KEY env variable.

    The module constructs correct API URL to send the data to based on the chain ID. A `chain_id -> instance_url` map
    is available in Chainscout API (which URL is defined in INDEXER_OPTIMISM_CHAINSCOUT_API_URL env variable) or
    can be defined with INDEXER_OPTIMISM_CHAINSCOUT_FALLBACK_MAP env variable in form of JSON object, e.g.:

    {10: "https://optimism.blockscout.com/", 8453: "https://base.blockscout.com/"}

    In production chains INDEXER_OPTIMISM_CHAINSCOUT_API_URL env should be defined as `https://chains.blockscout.com/api/chains/`.
    In local dev chains INDEXER_OPTIMISM_CHAINSCOUT_API_URL env should be omitted as the Chainscout doesn't have any info about
    some dev chain. For local dev case INDEXER_OPTIMISM_CHAINSCOUT_FALLBACK_MAP must be used.
  """

  use GenServer
  use Indexer.Fetcher

  require Logger

  alias Explorer.Chain
  alias Explorer.Chain.Hash
  alias Explorer.Chain.Optimism.InteropMessage
  alias Indexer.Fetcher.Optimism

  @fetcher_name :optimism_interop_messages_queue
  @api_endpoint_import "/api/v2/import/optimism/interop/"

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
    json_rpc_named_arguments = args[:json_rpc_named_arguments]
    {:ok, %{}, {:continue, json_rpc_named_arguments}}
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
  # - `_json_rpc_named_arguments`: Configuration parameters for the JSON RPC connection to RPC node.
  # - `_state`: Initial state of the fetcher (empty map when starting).
  #
  # ## Returns
  # - `{:noreply, state}` when the initialization is successful and the handling can start. The `state` contains
  #                       necessary parameters needed for the handling.
  # - `{:stop, :normal, %{}}` in case of error or when both env variables are not defined.
  @impl GenServer
  @spec handle_continue(EthereumJSONRPC.json_rpc_named_arguments(), map()) ::
          {:noreply, map()} | {:stop, :normal, map()}
  def handle_continue(_json_rpc_named_arguments, _state) do
    Logger.metadata(fetcher: @fetcher_name)

    # two seconds pause needed to avoid exceeding Supervisor restart intensity when DB issues
    :timer.sleep(2000)

    env = Application.get_all_env(:indexer)[__MODULE__]

    with false <- is_nil(env[:chainscout_api_url]) and env[:chainscout_fallback_map] == %{},
         private_key = env[:private_key] |> String.trim_leading("0x") |> Base.decode16!(case: :mixed),
         {:ok, _} <- ExSecp256k1.create_public_key(private_key),
         chain_id = Optimism.fetch_chain_id(),
         {:chain_id_is_nil, false} <- {:chain_id_is_nil, is_nil(chain_id)} do
      chainscout_map =
        env[:chainscout_fallback_map]
        |> Enum.map(fn {id, url} -> {String.to_integer(id), url} end)
        |> Enum.into(%{})

      Process.send(self(), :continue, [])

      {:noreply,
       %{
         chain_id: chain_id,
         chainscout_api_url: env[:chainscout_api_url],
         chainscout_map: chainscout_map,
         private_key: private_key
       }}
    else
      true ->
        # Chainscout API URL and fallback map are not defined, so we don't start this module
        Logger.warning(
          "Both INDEXER_OPTIMISM_CHAINSCOUT_API_URL and INDEXER_OPTIMISM_CHAINSCOUT_FALLBACK_MAP are not defined. The module #{__MODULE__} will not start."
        )

        {:stop, :normal, %{}}

      {:chain_id_is_nil, true} ->
        Logger.error("Cannot get chain ID from RPC.")
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
  #            and a private key for signing details.
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
          private_key: private_key
        } = state
      ) do
    updated_chainscout_map =
      current_chain_id
      |> InteropMessage.get_incomplete_messages()
      |> Enum.reduce(chainscout_map, fn message, chainscout_map_acc ->
        {instance_chain_id, post_data, post_data_to_sign} =
          if is_nil(message.relay_transaction_hash) do
            timestamp = DateTime.to_unix(message.timestamp)
            payload = "0x" <> Base.encode16(message.payload, case: :lower)

            data = %{
              sender: Hash.to_string(message.sender),
              target: Hash.to_string(message.target),
              nonce: message.nonce,
              init_chain_id: message.init_chain_id,
              init_transaction_hash: Hash.to_string(message.init_transaction_hash),
              timestamp: timestamp,
              relay_chain_id: message.relay_chain_id,
              payload: payload,
              signature: nil
            }

            data_to_sign =
              data.sender <>
              data.target <>
                Integer.to_string(message.nonce) <>
                Integer.to_string(message.init_chain_id) <>
                data.init_transaction_hash <>
                Integer.to_string(timestamp) <> Integer.to_string(message.relay_chain_id) <> payload

            {message.relay_chain_id, data, data_to_sign}
          else
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

            {message.init_chain_id, data, data_to_sign}
          end

        {:ok, {signature, _}} =
          post_data_to_sign
          |> ExKeccak.hash_256()
          |> ExSecp256k1.sign_compact(private_key)

        post_data_signed = %{post_data | signature: "0x" <> Base.encode16(signature, case: :lower)}

        url_from_map = Map.get(chainscout_map_acc, instance_chain_id)

        instance_url =
          with {:url_from_map_is_nil, true, _} <- {:url_from_map_is_nil, is_nil(url_from_map), url_from_map},
               info = InteropMessage.get_instance_info_by_chain_id(instance_chain_id, chainscout_api_url),
               {:url_from_chainscout_avail, true} <- {:url_from_chainscout_avail, not is_nil(info)} do
            info.instance_url
          else
            {:url_from_map_is_nil, false, url_from_map} ->
              String.trim_trailing(url_from_map, "/")

            {:url_from_chainscout_avail, false} ->
              nil
          end

        with false <- is_nil(instance_url),
             endpoint_url = instance_url <> @api_endpoint_import,
             response = post_json_request(endpoint_url, post_data_signed),
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

        if is_nil(instance_url) do
          chainscout_map_acc
        else
          Map.put(chainscout_map_acc, instance_chain_id, instance_url)
        end
      end)

    Process.send_after(self(), :continue, :timer.seconds(3))

    {:noreply, %{state | chainscout_map: updated_chainscout_map}}
  end

  @impl GenServer
  def handle_info({ref, _result}, state) do
    Process.demonitor(ref, [:flush])
    {:noreply, state}
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
          pl -> pl |> String.trim_leading("0x") |> Base.decode16!(case: :mixed)
        end

      %{
        sender: Map.get(response, "sender"),
        target: Map.get(response, "target"),
        nonce: message.nonce,
        init_chain_id: message.init_chain_id,
        init_transaction_hash: Map.get(response, "init_transaction_hash"),
        timestamp: timestamp,
        payload: payload
      }
    end
  end

  # Sends message's data to the given remote instance using HTTP POST request and returns a response from the instance.
  #
  # ## Parameters
  # - `url`: URL of the remote API endpoint to send the data to.
  # - `body`: A map with message's data.
  #
  # ## Returns
  # - A response map in case of success.
  # - `nil` in case of failure (failed HTTP request or invalid JSON response).
  @spec post_json_request(String.t(), map()) :: map() | nil
  defp post_json_request(url, body) do
    case HTTPoison.post(url, Jason.encode!(body), [{"Content-Type", "application/json"}]) do
      {:ok, %HTTPoison.Response{body: response_body, status_code: 200}} ->
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
