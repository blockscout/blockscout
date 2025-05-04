defmodule BlockScoutWeb.API.HealthController do
  use Phoenix.Controller, namespace: BlockScoutWeb

  import Plug.Conn

  alias Explorer.Chain.Health.Helper, as: HealthHelper
  alias Explorer.Migrator.MigrationStatus

  @ok_message "OK"
  @backfill_multichain_search_db_migration_name "backfill_multichain_search_db"
  @rollups [:arbitrum, :zksync, :optimism, :polygon_zkevm, :scroll]

  @doc """
  Handles health checks for the application.

  This endpoint is used to determine if the application is healthy and operational. It performs checks on the status of the blockchain data in both the database and the cache.

  ## Parameters

    - conn: The connection struct representing the current HTTP connection.
    - params: A map of parameters (not used in this function).

  ## Returns

    - The updated connection struct with the response sent.

  If the application is not running in standalone media worker mode, it retrieves the latest block number and timestamp from both the database and the cache. It then sends an HTTP 200 response with this information.
  """
  @spec health(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def health(conn, params) do
    health(conn, params, Application.get_env(:nft_media_handler, :standalone_media_worker?))
  end

  defp health(conn, _, false) do
    indexing_status = get_indexing_status()

    base_health_status =
      %{
        metadata: %{
          # todo: this key is left for backward compatibility
          # and should be removed after 8.0.0 release in favour of the new health check logic based on multiple modules
          latest_block: indexing_status.blocks.old,
          blocks: indexing_status.blocks.new
        }
      }

    metadata = Map.get(base_health_status, :metadata)

    health_status =
      if Application.get_env(:explorer, :chain_type) in @rollups do
        batches_indexing_status = indexing_status.batches

        base_health_status
        |> put_in([:metadata, :batches], batches_indexing_status)
        # todo: return this when "latest block" metric starts remain non-empty all time
        # |> Map.put(:healthy, indexing_status.blocks.new.healthy and batches_indexing_status.healthy)
        |> Map.put(:healthy, indexing_status.blocks.new.healthy)
      else
        base_health_status
        |> Map.put(:healthy, indexing_status.blocks.new.healthy)
      end

    # todo: this should be removed after 8.0.0. It is left for backward compatibility - it is artefact of the old response format.
    blocks_property = Map.get(Map.get(health_status, :metadata), :blocks)

    health_status_with_error =
      health_status
      |> (&if(Map.has_key?(metadata, :error),
            do: &1,
            else: Map.put(&1, :error, Map.get(blocks_property, :error))
          )).()

    status =
      if Map.get(health_status, :healthy) do
        :ok
      else
        500
      end

    send_resp(
      conn,
      status,
      health_status_with_error
      |> Jason.encode!()
    )
  end

  defp health(conn, _params, true) do
    send_resp(
      conn,
      :ok,
      %{
        "healthy" => true,
        "data" => %{}
      }
      |> Jason.encode!()
    )
  end

  @doc """
  Handles liveness checks for the application.

  This endpoint is used to determine if the application is running and able to handle requests.
  It responds with an HTTP 200 status and a predefined message.

  ## Parameters

    - conn: The connection struct representing the current HTTP connection.
    - _: A map of parameters (not used in this function).

  ## Returns

    - The updated connection struct with the response sent.
  """
  @spec liveness(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def liveness(conn, _) do
    send_resp(conn, :ok, @ok_message)
  end

  @doc """
  Handles readiness checks for the application.

  This endpoint is used to determine if the application is ready to handle incoming requests.
  It performs a conditional check on the application's environment configuration and responds with an HTTP 200 status and a predefined message.

  In the case of indexer/API application mode, it performs request in the DB to get the latest block.

  ## Parameters

    - conn: The connection struct representing the current HTTP connection.
    - _: A map of parameters (not used in this function).

  ## Returns

    - The updated connection struct with the response sent.
  """
  @spec readiness(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def readiness(conn, _) do
    unless Application.get_env(:nft_media_handler, :standalone_media_worker?) do
      HealthHelper.last_db_block_status()
    end

    send_resp(conn, :ok, @ok_message)
  end

  @doc """
  Handles the request to check the status of the multichain search database export.

  Fetches the migration status for the multichain search database export and returns a JSON response
  indicating whether the migration has finished and includes any associated metadata.

  ## Parameters
    - conn: The connection struct.
    - _params: The request parameters (not used in this function).

  ## Response
    - A JSON response with the migration status and metadata.

  ## Examples

      iex> conn = %Plug.Conn{}
      iex> multichain_search_db_export(conn, %{})
      %Plug.Conn{status: 200, resp_body: "{\"migration\":{\"finished\":false,\"meta\":{\"max_block_number\":6684354}}}"}
  """
  @spec multichain_search_db_export(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def multichain_search_db_export(conn, _) do
    case MigrationStatus.fetch(@backfill_multichain_search_db_migration_name) do
      %{status: status, meta: meta} = _migration ->
        response =
          %{
            migration: %{
              finished: status == "completed",
              metadata: meta
            }
          }
          |> Jason.encode!()

        send_resp(conn, :ok, response)

      _ ->
        send_resp(conn, :internal_server_error, Jason.encode!(%{error: "Failed to fetch migration status"}))
    end
  end

  @spec get_indexing_status() :: map()
  def get_indexing_status do
    health_status = HealthHelper.get_indexing_health_data()

    blocks_old = old_blocks_indexing_status(health_status)
    blocks_new = new_blocks_indexing_status(health_status)

    common_status =
      %{
        blocks: %{old: blocks_old, new: blocks_new}
      }

    status =
      if Application.get_env(:explorer, :chain_type) in @rollups do
        batches = batches_indexing_status(health_status)

        common_status
        |> Map.put(:batches, batches)
      else
        common_status
      end

    status
  end

  # todo: it should be removed after 8.0.0 release in favour of the new health check logic based on multiple modules
  defp old_blocks_indexing_status(health_status) do
    latest_block_timestamp_from_db =
      if is_nil(health_status[:health_latest_block_timestamp_from_db]) do
        nil
      else
        {:ok, latest_block_timestamp_from_db} =
          DateTime.from_unix(Decimal.to_integer(health_status[:health_latest_block_timestamp_from_db]))

        latest_block_timestamp_from_db
      end

    latest_block_timestamp_from_cache =
      if is_nil(health_status[:health_latest_block_timestamp_from_cache]) do
        nil
      else
        {:ok, latest_block_timestamp_from_cache} =
          DateTime.from_unix(Decimal.to_integer(health_status[:health_latest_block_timestamp_from_cache]))

        latest_block_timestamp_from_cache
      end

    %{
      db: %{
        number: to_string(health_status[:health_latest_block_number_from_db]),
        timestamp: to_string(latest_block_timestamp_from_db)
      },
      cache: %{
        number: to_string(health_status[:health_latest_block_number_from_cache]),
        timestamp: to_string(latest_block_timestamp_from_cache)
      }
    }
  end

  defp new_blocks_indexing_status(health_status) do
    latest_block_timestamp_from_db =
      if is_nil(health_status[:health_latest_block_timestamp_from_db]) do
        nil
      else
        {:ok, latest_block_timestamp_from_db} =
          DateTime.from_unix(Decimal.to_integer(health_status[:health_latest_block_timestamp_from_db]))

        latest_block_timestamp_from_db
      end

    latest_block_timestamp_from_cache =
      if is_nil(health_status[:health_latest_block_timestamp_from_cache]) do
        nil
      else
        {:ok, latest_block_timestamp_from_cache} =
          DateTime.from_unix(Decimal.to_integer(health_status[:health_latest_block_timestamp_from_cache]))

        latest_block_timestamp_from_cache
      end

    {healthy?, code, message} =
      case HealthHelper.blocks_indexing_healthy?(health_status) do
        true -> {true, 0, nil}
        other -> other
      end

    base_response =
      %{
        healthy: healthy?,
        latest_block: %{
          db: %{
            number: to_string(health_status[:health_latest_block_number_from_db]),
            timestamp: to_string(latest_block_timestamp_from_db)
          },
          cache: %{
            number: to_string(health_status[:health_latest_block_number_from_cache]),
            timestamp: to_string(latest_block_timestamp_from_cache)
          },
          node: %{
            number: to_string(health_status[:health_latest_block_number_from_node])
          }
        }
      }

    response =
      if healthy? do
        base_response
      else
        Map.put(base_response, :error, error(code, message))
      end

    response
  end

  defp batches_indexing_status(health_status) do
    latest_batch_timestamp_from_db =
      if is_nil(health_status[:health_latest_batch_timestamp_from_db]) do
        nil
      else
        {:ok, latest_batch_timestamp_from_db} =
          DateTime.from_unix(Decimal.to_integer(health_status[:health_latest_batch_timestamp_from_db]))

        latest_batch_timestamp_from_db
      end

    {healthy?, code, message} =
      case HealthHelper.batches_indexing_healthy?(health_status) do
        true -> {true, 0, nil}
        other -> other
      end

    base_response =
      %{
        healthy: healthy?,
        latest_batch: %{
          db: %{
            number: to_string(health_status[:health_latest_batch_number_from_db]),
            timestamp: to_string(latest_batch_timestamp_from_db),
            average_batch_time: to_string(health_status[:health_latest_batch_average_time_from_db])
          }
        }
      }

    response =
      if healthy? do
        base_response
      else
        Map.put(base_response, :error, error(code, message))
      end

    response
  end

  defp error(code, message) do
    %{
      code: code,
      message: message
    }
  end
end
