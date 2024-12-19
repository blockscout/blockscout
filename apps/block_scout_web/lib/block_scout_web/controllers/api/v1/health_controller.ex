defmodule BlockScoutWeb.API.V1.HealthController do
  use Phoenix.Controller, namespace: BlockScoutWeb

  import Plug.Conn

  alias Explorer.Chain
  alias Explorer.Migrator.MigrationStatus
  alias Timex.Duration

  @ok_message "OK"
  @backfill_multichain_search_db_migration_name "backfill_multichain_search_db"

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
    with {:ok, latest_block_number_from_db, latest_block_timestamp_from_db} <- Chain.last_db_block_status(),
         {:ok, latest_block_number_from_cache, latest_block_timestamp_from_cache} <- Chain.last_cache_block_status() do
      send_resp(
        conn,
        :ok,
        result(
          latest_block_number_from_db,
          latest_block_timestamp_from_db,
          latest_block_number_from_cache,
          latest_block_timestamp_from_cache
        )
      )
    else
      status -> send_resp(conn, :internal_server_error, encoded_error(status))
    end
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
      Chain.last_db_block_status()
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

  defp result(
         latest_block_number_from_db,
         latest_block_timestamp_from_db,
         latest_block_number_from_cache,
         latest_block_timestamp_from_cache
       ) do
    %{
      healthy: true,
      metadata: %{
        latest_block: %{
          db: %{
            number: to_string(latest_block_number_from_db),
            timestamp: to_string(latest_block_timestamp_from_db)
          },
          cache: %{
            number: to_string(latest_block_number_from_cache),
            timestamp: to_string(latest_block_timestamp_from_cache)
          }
        }
      }
    }
    |> Jason.encode!()
  end

  defp encoded_error({:error, :no_blocks}) do
    %{
      healthy: false,
      error: error(5002, "There are no blocks in the DB.")
    }
    |> Jason.encode!()
  end

  defp encoded_error({:stale, number, timestamp}) do
    healthy_blocks_period = Application.get_env(:explorer, :healthy_blocks_period)

    healthy_blocks_period_minutes_formatted =
      healthy_blocks_period
      |> Duration.from_milliseconds()
      |> Duration.to_minutes()
      |> trunc()

    %{
      healthy: false,
      error:
        error(
          5001,
          "There are no new blocks in the DB for the last #{healthy_blocks_period_minutes_formatted} mins. Check the healthiness of the JSON RPC archive node or the DB."
        ),
      metadata: %{
        latest_block: %{
          number: to_string(number),
          timestamp: to_string(timestamp)
        }
      }
    }
    |> Jason.encode!()
  end

  defp error(code, message) do
    %{
      code: code,
      message: message
    }
  end
end
