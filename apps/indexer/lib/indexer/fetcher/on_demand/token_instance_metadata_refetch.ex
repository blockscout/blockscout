defmodule Indexer.Fetcher.OnDemand.TokenInstanceMetadataRefetch do
  @moduledoc """
  Re-fetches token instance metadata.
  """

  require Logger

  use GenServer
  use Indexer.Fetcher, restart: :permanent

  alias Explorer.Chain.Cache.Counters.Helper, as: CountersHelper
  alias Explorer.Chain.Events.Publisher
  alias Explorer.Chain.Token.Instance, as: TokenInstance
  alias Explorer.SmartContract.Reader
  alias Explorer.Token.MetadataRetriever
  alias Explorer.Utility.TokenInstanceMetadataRefetchAttempt
  alias Indexer.Fetcher.TokenInstance.Helper, as: TokenInstanceHelper
  alias Indexer.NFTMediaHandler.Queue

  @max_delay :timer.hours(168)

  @spec trigger_refetch(TokenInstance.t()) :: :ok
  def trigger_refetch(token_instance) do
    GenServer.cast(__MODULE__, {:refetch, token_instance})
  end

  defp fetch_metadata(token_instance, state) do
    with {:retries_number, {retries_number, updated_at}} <-
           {:retries_number,
            TokenInstanceMetadataRefetchAttempt.get_retries_number(
              token_instance.token_contract_address_hash,
              token_instance.token_id
            )},
         updated_at_ms = DateTime.to_unix(updated_at, :millisecond),
         {:retry, true} <-
           {:retry,
            CountersHelper.current_time() - updated_at_ms >
              threshold(retries_number)} do
      fetch_and_broadcast_metadata(token_instance, state)
    else
      {:retries_number, nil} ->
        fetch_and_broadcast_metadata(token_instance, state)

      {:retry, false} ->
        :ok
    end
  end

  defp fetch_and_broadcast_metadata(token_instance, _state) do
    from_base_uri? = Application.get_env(:indexer, TokenInstanceHelper)[:base_uri_retry?]

    token_id = TokenInstanceHelper.prepare_token_id(token_instance.token_id)
    contract_address_hash_string = to_string(token_instance.token_contract_address_hash)

    request =
      TokenInstanceHelper.prepare_request(
        token_instance.token.type,
        contract_address_hash_string,
        token_id,
        false
      )

    result =
      case Reader.query_contracts([request], TokenInstanceHelper.erc_721_1155_abi(), [], false) do
        [ok: [uri]] ->
          {:ok, [uri]}

        _ ->
          nil
      end

    with {:empty_result, false} <- {:empty_result, is_nil(result)},
         {:fetched_metadata, {:ok, %{metadata: metadata}}} <-
           {:fetched_metadata, MetadataRetriever.fetch_json(result, token_id, nil, from_base_uri?)} do
      TokenInstance.set_metadata(token_instance, metadata)

      Publisher.broadcast(
        %{fetched_token_instance_metadata: [to_string(token_instance.token_contract_address_hash), token_id, metadata]},
        :on_demand
      )

      Queue.process_new_instances([%TokenInstance{token_instance | metadata: metadata}])
    else
      {:empty_result, true} ->
        :ok

      {:fetched_metadata, error} ->
        Logger.error(fn ->
          "Error while refetching metadata for {#{token_instance.token_contract_address_hash}, #{token_id}}: #{inspect(error)}"
        end)

        TokenInstanceMetadataRefetchAttempt.insert_retries_number(
          token_instance.token_contract_address_hash,
          token_instance.token_id
        )
    end
  end

  def start_link([init_opts, server_opts]) do
    GenServer.start_link(__MODULE__, init_opts, server_opts)
  end

  @impl true
  def init(json_rpc_named_arguments) do
    {:ok, %{json_rpc_named_arguments: json_rpc_named_arguments}}
  end

  @impl true
  def handle_cast({:refetch, token_instance}, state) do
    fetch_metadata(token_instance, state)

    {:noreply, state}
  end

  defp update_threshold_ms do
    Application.get_env(:indexer, __MODULE__)[:threshold]
  end

  defp threshold(retries_number) do
    delay_in_ms = trunc(update_threshold_ms() * :math.pow(2, retries_number))

    min(delay_in_ms, @max_delay)
  end
end
