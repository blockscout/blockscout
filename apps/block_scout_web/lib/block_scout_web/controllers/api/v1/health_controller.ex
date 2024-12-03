defmodule BlockScoutWeb.API.V1.HealthController do
  use Phoenix.Controller, namespace: BlockScoutWeb

  import Plug.Conn

  alias Explorer.Chain
  alias Explorer.Migrator.MigrationStatus
  alias Timex.Duration

  @ok_message "OK"
  @backfill_multichain_search_db_migration_name "backfill_multichain_search_db"

  @spec health(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def health(conn, _) do
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

  @spec liveness(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def liveness(conn, _) do
    send_resp(conn, :ok, @ok_message)
  end

  @spec readiness(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def readiness(conn, _) do
    Chain.last_db_block_status()

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
    migration = MigrationStatus.fetch(@backfill_multichain_search_db_migration_name)
    migration_status_finished? = migration.status == "completed"

    response =
      %{
        migration: %{
          finished: migration_status_finished?,
          metadata: migration.meta
        }
      }
      |> Jason.encode!()

    send_resp(conn, :ok, response)
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
