defmodule Indexer.Fetcher.Optimism.InteropMessageQueue do
  @moduledoc """
    ...
  """

  use GenServer
  use Indexer.Fetcher

  require Logger

  alias Explorer.Chain
  alias Explorer.Chain.Optimism.InteropMessage
  alias Indexer.Fetcher.Optimism

  @fetcher_name :optimism_interop_messages_queue

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
  # during initialization. It checks the value of INDEXER_OPTIMISM_CHAINSCOUT_API_URL and INDEXER_OPTIMISM_CHAINSCOUT_FALLBACK_MAP
  # env variables and starts the handling loop.
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

    with chain_id = Optimism.fetch_chain_id(json_rpc_named_arguments),
         {:chain_id_is_nil, false} <- {:chain_id_is_nil, is_nil(chain_id)},
         false <- is_nil(env[:chainscout_api_url]) and env[:chainscout_fallback_map] == %{} do
      Process.send(self(), :continue, [])

      {:noreply,
       %{
         chain_id: chain_id,
         chainscout_api_url: env[:chainscout_api_url],
         chainscout_map: env[:chainscout_fallback_map]
       }}
    else
      true ->
        # Chainscout API URL and fallback map are not defined, so we don't start this module
        Logger.warning("Both INDEXER_OPTIMISM_CHAINSCOUT_API_URL and INDEXER_OPTIMISM_CHAINSCOUT_FALLBACK_MAP are not defined. The module #{__MODULE__} will not start")
        {:stop, :normal, %{}}

      {:chain_id_is_nil, true} ->
        Logger.error("Cannot get chain ID from RPC.")
        {:stop, :normal, %{}}
    end
  end

  # ...
  #
  # Performs the main handling loop for the specified block range. The block range is split into chunks.
  # Max size of a chunk is defined by INDEXER_OPTIMISM_L2_INTEROP_START_BLOCK env variable.
  #
  # If there are reorg blocks in the block range, the reorgs are handled. In a normal situation,
  # the realtime block range is formed by `handle_info({:chain_event, :blocks, :realtime, blocks}, state)`
  # handler.
  #
  # ## Parameters
  # - `:continue`: The GenServer message.
  # - `state`: The current state of the fetcher containing block range, max chunk size, etc.
  #
  # ## Returns
  # - `{:noreply, state}` tuple where `state` is the new state of the fetcher which can have updated block
  #    range and other parameters.
  @impl GenServer
  def handle_info(
        :continue,
        %{
          chain_id: current_chain_id,
          chainscout_api_url: chainscout_api_url,
          chainscout_map: chainscout_map
        } = state
      ) do
    updated_chainscout_map =
      current_chain_id
      |> InteropMessage.get_incomplete_messages()
      |> Enum.reduce(chainscout_map, fn message, chainscout_map_acc ->
        {instance_chain_id, post_data} =
          if is_nil(message.relay_transaction_hash) do
            {
              message.relay_chain_id,
              %{
                sender: message.sender,
                target: message.target,
                nonce: message.nonce,
                init_chain_id: message.init_chain_id,
                init_transaction_hash: message.init_transaction_hash,
                timestamp: DateTime.to_unix(message.timestamp),
                payload: "0x" <> Base.encode16(message.payload, case: :lower)
              }
            }
          else
            {
              message.init_chain_id,
              %{
                nonce: message.nonce,
                init_chain_id: message.init_chain_id,
                relay_transaction_hash: message.relay_transaction_hash,
                failed: message.failed
              }
            }
          end

        instance_url =
          case Map.get(chainscout_map_acc, instance_chain_id) do
            nil -> get_api_url_by_chain_id(instance_chain_id, chainscout_api_url)
            url -> url
          end

        if is_nil(instance_url) do
          chainscout_map_acc
        else
          case post_json_request(instance_url, post_data) do
            nil -> nil
            response ->
              to_import =
                if is_nil(message.relay_transaction_hash) do
                  # this is outgoing message without relay part, so we sent message details to the target instance
                  # and got relay details from the target instance
                  [%{
                    nonce: message.nonce,
                    init_chain_id: message.init_chain_id,
                    relay_transaction_hash: Map.get(response, "relay_transaction_hash"),
                    failed: Map.get(response, "failed")
                  }]
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

                  [%{
                    sender: Map.get(response, "sender"),
                    target: Map.get(response, "target"),
                    nonce: message.nonce,
                    init_chain_id: message.init_chain_id,
                    init_transaction_hash: Map.get(response, "init_transaction_hash"),
                    timestamp: timestamp,
                    payload: payload
                  }]
                end

              {:ok, _} =
                Chain.import(%{
                  optimism_interop_messages: %{params: to_import},
                  timeout: :infinity
                })

              Logger.info("Message details successfully sent to #{instance_url}. Request body: #{inspect(post_data)}. Response body: #{inspect(response)}")
          end

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

  defp post_json_request(url, body) do
    case HTTPoison.post(url, Jason.encode!(body), [{"Content-Type", "application/json"}]) do
      {:ok, %HTTPoison.Response{body: response_body, status_code: 200}} ->
        case Jason.decode(response_body) do
          {:ok, response} ->
            response

          _ ->
            Logger.error("Cannot decode response from #{url}. Response body: #{inspect(response_body)}. Request body: #{body}")
            nil
        end

      other ->
        Logger.error("Cannot post HTTP request to #{url}. Reason: #{inspect(other)}. Body: #{inspect(body)}")
        nil
    end
  end

  defp get_api_url_by_chain_id(chain_id, nil) do
    Logger.error("Unknown remote API URL for chain ID #{chain_id}. Please, define that in INDEXER_OPTIMISM_CHAINSCOUT_FALLBACK_MAP or define INDEXER_OPTIMISM_CHAINSCOUT_API_URL.")
    nil
  end

  defp get_api_url_by_chain_id(chain_id, chainscout_api_url) do
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
      String.trim_trailing(explorer_url, "/") <> "/api/v2/optimism/interop/send"
    else
      true ->
        Logger.error("Cannot get explorer URL from #{url}")
        nil

      other ->
        Logger.error("Cannot get HTTP response from #{url}. Reason: #{inspect(other)}")
        nil
    end
  end
end
