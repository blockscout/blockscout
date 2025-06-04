defmodule Indexer.Fetcher.Optimism.Interop.MultichainExport do
  @moduledoc """
    Finds messages without `sent_to_multichain` flag in the `op_interop_messages` database table and
    sends them to the Multichain service using its API.

    The found messages are combined into a batch and the batch is sent to the remote API. The batch max
    size is defined with the optional INDEXER_OPTIMISM_MULTICHAIN_BATCH_SIZE env variable having
    a default value. Once the found messages are sent, the module starts the next iteration for another
    batch of messages, and so on.

    The Multichain API endpoint URL is defined with MICROSERVICE_MULTICHAIN_SEARCH_URL env variable.
    API key for the remote service is defined with MICROSERVICE_MULTICHAIN_SEARCH_API_KEY env variable.
  """

  use GenServer
  use Indexer.Fetcher

  require Logger

  import Ecto.Query
  import Explorer.Helper, only: [valid_url?: 1]
  import Indexer.Fetcher.Optimism.Interop.Helper, only: [log_cant_get_chain_id_from_rpc: 0]

  alias Ecto.Multi
  alias Explorer.Chain.Hash
  alias Explorer.Chain.Optimism.InteropMessage
  alias Explorer.MicroserviceInterfaces.MultichainSearch
  alias Explorer.Repo
  alias Indexer.Fetcher.Optimism

  @fetcher_name :optimism_interop_multichain_export

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
  def init(_args) do
    {:ok, %{}, {:continue, nil}}
  end

  # Initialization function which is used instead of `init` to avoid Supervisor's stop in case of any critical issues
  # during initialization. It checks the value of MICROSERVICE_MULTICHAIN_SEARCH_URL and MICROSERVICE_MULTICHAIN_SEARCH_API_KEY
  # env variables and starts the handling loop.
  #
  # Also, the function fetches the current chain id to use it in the handler.
  #
  # When the initialization succeeds, the `:continue` message is sent to GenServer to start the handler loop.
  #
  # ## Parameters
  # - `_state`: Initial state of the fetcher (empty map when starting).
  #
  # ## Returns
  # - `{:noreply, state}` when the initialization is successful and the handling can start. The `state` contains
  #                       necessary parameters needed for the handling.
  # - `{:stop, :normal, %{}}` in case of error or when one of env variables is not defined.
  @impl GenServer
  @spec handle_continue(nil, map()) :: {:noreply, map()} | {:stop, :normal, map()}
  def handle_continue(nil, _state) do
    Logger.metadata(fetcher: @fetcher_name)

    # two seconds pause needed to avoid exceeding Supervisor restart intensity when DB issues
    :timer.sleep(2000)

    env = Application.get_all_env(:indexer)[__MODULE__]

    multichain_api_url = MultichainSearch.batch_import_url()
    multichain_api_key = MultichainSearch.api_key()

    with {:api_url_is_valid, true} <- {:api_url_is_valid, valid_url?(multichain_api_url)},
         {:api_key_is_nil, false} <- {:api_key_is_nil, is_nil(multichain_api_key)},
         chain_id = Optimism.fetch_chain_id(),
         {:chain_id_is_nil, false} <- {:chain_id_is_nil, is_nil(chain_id)} do
      Process.send(self(), :continue, [])

      {:noreply,
       %{
         chain_id: chain_id,
         multichain_api_url: multichain_api_url,
         multichain_api_key: multichain_api_key,
         batch_size: env[:batch_size]
       }}
    else
      {:api_url_is_valid, false} ->
        # Multichain service API URL is not defined, so we don't start this module
        Logger.warning(
          "MICROSERVICE_MULTICHAIN_SEARCH_URL env variable is invalid or not defined. The module #{__MODULE__} will not start."
        )

        {:stop, :normal, %{}}

      {:api_key_is_nil, true} ->
        Logger.error(
          "MICROSERVICE_MULTICHAIN_SEARCH_API_KEY env variable is not defined. The module #{__MODULE__} will not start."
        )

        {:stop, :normal, %{}}

      {:chain_id_is_nil, true} ->
        log_cant_get_chain_id_from_rpc()
        {:stop, :normal, %{}}
    end
  end

  # Performs the main handling loop scanning for unsent part of messages.
  #
  # Details of each unsent message part are prepared and sent to the remote multichain instance through its API.
  #
  # ## Parameters
  # - `:continue`: The GenServer message.
  # - `state`: The current state of the fetcher containing the current chain ID, API URL and key, and batch size.
  #
  # ## Returns
  # - `{:noreply, state}` tuple.
  @impl GenServer
  def handle_info(
        :continue,
        %{
          chain_id: current_chain_id,
          multichain_api_url: multichain_api_url,
          multichain_api_key: multichain_api_key,
          batch_size: batch_size
        } = state
      ) do
    messages = InteropMessage.get_messages_for_multichain_export(current_chain_id, batch_size)

    data = prepare_post_data(current_chain_id, messages, multichain_api_key)

    if post_json_request(multichain_api_url, data) do
      {:ok, _} =
        messages
        |> Enum.reduce(Multi.new(), fn message, multi_acc ->
          Multi.update_all(
            multi_acc,
            {:message, message.nonce, message.init_chain_id},
            from(m in InteropMessage, where: m.nonce == ^message.nonce and m.init_chain_id == ^message.init_chain_id),
            set: [sent_to_multichain: true]
          )
        end)
        |> Repo.transaction()

      Logger.info("#{length(messages)} item(s) were successfully sent to the Multichain service.")
    end

    if messages == [] do
      Logger.info("There are no items to send to the Multichain service. Retrying in a few moments...")
    end

    Process.send_after(self(), :continue, :timer.seconds(3))

    {:noreply, state}
  end

  @impl GenServer
  def handle_info({ref, _result}, state) do
    Process.demonitor(ref, [:flush])
    {:noreply, state}
  end

  # Prepares data to send as POST request to the remote multichain API endpoint.
  #
  # ## Parameters
  # - `current_chain_id`: The current chain ID.
  # - `messages`: A list of maps containing the messages data.
  # - `api_key`: API key to access the remote import endpoint.
  #
  # ## Returns
  # - The prepared data map if the `messages` list is not empty.
  # - `nil` if the `messages` list is empty.
  @spec prepare_post_data(non_neg_integer(), [map()], String.t()) :: map() | nil
  defp prepare_post_data(_current_chain_id, [], _api_key), do: nil

  defp prepare_post_data(current_chain_id, messages, api_key) do
    interop_messages =
      messages
      |> Enum.map(fn message ->
        if message.init_chain_id == current_chain_id do
          # this is `init` part of an outgoing message
          %{
            init: %{
              sender_address_hash: Hash.to_string(message.sender_address_hash),
              target_address_hash: Hash.to_string(message.target_address_hash),
              nonce: Integer.to_string(message.nonce),
              init_chain_id: Integer.to_string(message.init_chain_id),
              init_transaction_hash: Hash.to_string(message.init_transaction_hash),
              timestamp: Integer.to_string(DateTime.to_unix(message.timestamp)),
              relay_chain_id: Integer.to_string(message.relay_chain_id),
              payload: message.payload,
              transfer_token_address_hash: message.transfer_token_address_hash,
              transfer_from_address_hash: message.transfer_from_address_hash,
              transfer_to_address_hash: message.transfer_to_address_hash,
              transfer_amount:
                if(not is_nil(message.transfer_amount), do: Decimal.to_string(message.transfer_amount, :normal))
            }
          }
        else
          # this is `relay` part of an incoming message
          %{
            relay: %{
              nonce: Integer.to_string(message.nonce),
              init_chain_id: Integer.to_string(message.init_chain_id),
              relay_chain_id: Integer.to_string(message.relay_chain_id),
              relay_transaction_hash: Hash.to_string(message.relay_transaction_hash),
              failed: message.failed
            }
          }
        end
      end)

    %{
      chain_id: Integer.to_string(current_chain_id),
      interop_messages: interop_messages,
      api_key: api_key
    }
  end

  # Sends message's data to the given remote multichain instance using HTTP POST request.
  #
  # ## Parameters
  # - `url`: URL of the remote API endpoint to send the data to.
  # - `body`: A map with message's data.
  #
  # ## Returns
  # - `true` in case of success.
  # - `false` in case of failure.
  @spec post_json_request(String.t(), map() | nil) :: boolean()
  defp post_json_request(_url, nil), do: false

  defp post_json_request(url, body) do
    timeout = 8_000
    recv_timeout = 5_000

    client = Tesla.client([{Tesla.Middleware.Timeout, timeout: recv_timeout}], Tesla.Adapter.Mint)
    json_body = Jason.encode!(body)
    headers = [{"Content-Type", "application/json"}]

    # Mint adapter doesn't support sending more than 65535 bytes when using HTTP/2, so we use HTTP/1
    opts = [adapter: [timeout: recv_timeout, transport_opts: [timeout: timeout], protocols: [:http1]]]

    case Tesla.post(client, url, json_body, headers: headers, opts: opts) do
      {:ok, %{status: 200}} ->
        true

      reason ->
        Logger.error("Cannot post HTTP request to #{url}. Reason: #{inspect(reason)}. Body: #{inspect(json_body)}")
        false
    end
  end
end
