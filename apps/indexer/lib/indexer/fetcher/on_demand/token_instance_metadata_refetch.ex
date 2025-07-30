defmodule Indexer.Fetcher.OnDemand.TokenInstanceMetadataRefetch do
  @moduledoc """
  Re-fetches token instance metadata.
  """

  require Logger

  use GenServer
  use Indexer.Fetcher, restart: :permanent

  alias EthereumJSONRPC.NFT
  alias Explorer.Chain.Cache.Counters.Helper, as: CountersHelper
  alias Explorer.Chain.Events.Publisher
  alias Explorer.Chain.Token.Instance, as: TokenInstance
  alias Explorer.Utility.{RateLimiter, TokenInstanceMetadataRefetchAttempt}
  alias Indexer.Fetcher.TokenInstance.Helper
  alias Indexer.NFTMediaHandler.Queue

  @max_delay :timer.hours(168)

  @spec trigger_refetch(String.t() | nil, TokenInstance.t()) :: :ok
  def trigger_refetch(caller \\ nil, token_instance) do
    case RateLimiter.check_rate(caller, :on_demand) do
      :allow -> GenServer.cast(__MODULE__, {:refetch, token_instance})
      :deny -> :ok
    end
  end

  defp fetch_metadata(token_instance) do
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
      fetch_and_broadcast_metadata(token_instance)
    else
      {:retries_number, nil} ->
        fetch_and_broadcast_metadata(token_instance)

      {:retry, false} ->
        Publisher.broadcast(
          %{
            not_fetched_token_instance_metadata: [
              to_string(token_instance.token_contract_address_hash),
              NFT.prepare_token_id(token_instance.token_id),
              "retry_cooldown"
            ]
          },
          :on_demand
        )

        :ok
    end
  end

  defp fetch_and_broadcast_metadata(
         %{token_id: token_id, token_contract_address_hash: token_contract_address_hash} = token_instance
       ) do
    case Helper.batch_prepare_instances_insert_params([
           %{contract_address_hash: token_contract_address_hash, token_id: token_id}
         ]) do
      [%{error: nil, metadata: metadata} = result] ->
        TokenInstance.set_metadata(token_instance, result)

        Publisher.broadcast(
          %{
            fetched_token_instance_metadata: [
              to_string(token_contract_address_hash),
              NFT.prepare_token_id(token_id),
              metadata
            ]
          },
          :on_demand
        )

        Queue.process_new_instances([%TokenInstance{token_instance | metadata: metadata}])

      [%{error: error}] ->
        Logger.error(fn ->
          "Error while refetching metadata for {#{token_contract_address_hash}, #{token_id}}: #{inspect(error)}"
        end)

        Publisher.broadcast(
          %{
            not_fetched_token_instance_metadata: [
              to_string(token_contract_address_hash),
              NFT.prepare_token_id(token_id),
              "error"
            ]
          },
          :on_demand
        )

        TokenInstanceMetadataRefetchAttempt.insert_retries_number(
          token_contract_address_hash,
          token_id
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
    fetch_metadata(token_instance)

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
