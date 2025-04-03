defmodule Explorer.Chain.Health.Monitor do
  @moduledoc """
  This module provides functionality for monitoring of the application health.
  Currently, it includes monitoring of blocks and batches indexing status.
  """
  use GenServer
  import Ecto.Query, only: [from: 2]
  import EthereumJSONRPC, only: [quantity_to_integer: 1]
  alias EthereumJSONRPC.Utility.EndpointAvailabilityChecker
  alias Explorer.Chain.Arbitrum.Reader.Common, as: ArbitrumReaderCommon
  alias Explorer.Chain.Cache.Counters.LastFetchedCounter
  alias Explorer.Chain.Health.Helper, as: HealthHelper
  alias Explorer.Chain.Optimism.Reader, as: OptimismReader
  alias Explorer.Chain.PolygonZkevm.Reader, as: PolygonZkevmReader
  alias Explorer.Chain.Scroll.Reader, as: ScrollReader
  alias Explorer.Chain.ZkSync.Reader, as: ZkSyncReader
  alias Explorer.Repo

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @impl true
  def init(state) do
    schedule_work()
    {:ok, state}
  end

  @impl true
  def handle_info(:work, state) do
    perform_work()
    schedule_work()
    {:noreply, state}
  end

  defp schedule_work do
    Process.send_after(self(), :work, Application.get_env(:explorer, __MODULE__)[:check_interval])
  end

  defp perform_work do
    json_rpc_named_arguments = Application.get_env(:explorer, :json_rpc_named_arguments)

    with {latest_block_number_from_db, latest_block_timestamp_from_db} <- HealthHelper.last_db_block(),
         {latest_block_number_from_cache, latest_block_timestamp_from_cache} <-
           HealthHelper.last_cache_block(),
         {:ok, latest_block_number_from_node} <-
           EndpointAvailabilityChecker.fetch_latest_block_number(json_rpc_named_arguments) do
      now = DateTime.utc_now()

      base_params = [
        %{
          counter_type: "health_latest_block_number_from_db",
          value: latest_block_number_from_db,
          inserted_at: now,
          updated_at: now
        },
        %{
          counter_type: "health_latest_block_timestamp_from_db",
          value: DateTime.to_unix(latest_block_timestamp_from_db),
          inserted_at: now,
          updated_at: now
        },
        %{
          counter_type: "health_latest_block_number_from_cache",
          value: latest_block_number_from_cache,
          inserted_at: now,
          updated_at: now
        },
        %{
          counter_type: "health_latest_block_timestamp_from_cache",
          value: DateTime.to_unix(latest_block_timestamp_from_cache),
          inserted_at: now,
          updated_at: now
        },
        %{
          counter_type: "health_latest_block_number_from_node",
          value: quantity_to_integer(latest_block_number_from_node),
          inserted_at: now,
          updated_at: now
        }
      ]

      batch_info =
        case Application.get_env(:explorer, :chain_type) do
          :arbitrum ->
            get_latest_batch_info_from_module(ArbitrumReaderCommon)

          :zksync ->
            get_latest_batch_info_from_module(ZkSyncReader)

          :optimism ->
            get_latest_batch_info_from_module(OptimismReader)

          :polygon_zkevm ->
            get_latest_batch_info_from_module(PolygonZkevmReader)

          :scroll ->
            get_latest_batch_info_from_module(ScrollReader)

          _ ->
            nil
        end

      params =
        if batch_info do
          base_params ++
            [
              %{
                counter_type: "health_latest_batch_number_from_db",
                value: batch_info.number,
                inserted_at: now,
                updated_at: now
              },
              %{
                counter_type: "health_latest_batch_timestamp_from_db",
                value: DateTime.to_unix(batch_info.timestamp),
                inserted_at: now,
                updated_at: now
              },
              %{
                counter_type: "health_latest_batch_average_time_from_db",
                value: batch_info.average_batch_time,
                inserted_at: now,
                updated_at: now
              }
            ]
        else
          base_params
        end

      Repo.insert_all(LastFetchedCounter, params,
        on_conflict: on_conflict(),
        conflict_target: [:counter_type]
      )
    end
  end

  defp on_conflict do
    from(
      last_fetched_counter in LastFetchedCounter,
      update: [
        set: [
          value: fragment("EXCLUDED.value"),
          updated_at: fragment("EXCLUDED.updated_at")
        ]
      ]
    )
  end

  defp get_latest_batch_info_from_module(module) do
    case module.get_latest_batch_info(api?: true) do
      {:ok,
       %{
         latest_batch_number: latest_batch_number,
         latest_batch_timestamp: latest_batch_timestamp,
         average_batch_time: average_batch_time
       }} ->
        %{
          number: latest_batch_number,
          timestamp: latest_batch_timestamp,
          average_batch_time: average_batch_time
        }

      _ ->
        nil
    end
  end
end
