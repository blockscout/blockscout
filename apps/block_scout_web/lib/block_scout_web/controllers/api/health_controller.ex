# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule BlockScoutWeb.API.HealthController do
  use Phoenix.Controller, namespace: BlockScoutWeb

  import Plug.Conn

  alias Explorer.Chain.Health.Helper, as: HealthHelper
  alias Explorer.Migrator.MigrationStatus

  @ok_message "OK"
  @backfill_multichain_search_db_migration_name "backfill_multichain_search_db"
  @rollups [:arbitrum, :zksync, :optimism, :scroll]
  # Chain types that have deposits/withdrawals data. zkSync is excluded (no such data model),
  # while ethereum is included (beacon deposits/withdrawals) even though it has no batches.
  @chain_types_with_messages [:arbitrum, :optimism, :scroll, :ethereum]

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
          blocks: indexing_status.blocks
        }
      }

    metadata = Map.get(base_health_status, :metadata)

    chain_type = Application.get_env(:explorer, :chain_type)

    health_status =
      base_health_status
      |> maybe_put_batches(indexing_status, chain_type)
      |> maybe_put_deposits_and_withdrawals(indexing_status, chain_type)
      |> Map.put(:healthy, indexing_status.blocks.healthy)

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
    if !Application.get_env(:nft_media_handler, :standalone_media_worker?) do
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

    blocks = blocks_indexing_status(health_status)

    common_status =
      %{
        blocks: blocks
      }

    chain_type = Application.get_env(:explorer, :chain_type)

    common_status
    |> maybe_add_batches(health_status, chain_type)
    |> maybe_add_deposits_and_withdrawals(health_status, chain_type)
  end

  defp maybe_add_batches(status, health_status, chain_type) when chain_type in @rollups do
    Map.put(status, :batches, batches_indexing_status(health_status))
  end

  defp maybe_add_batches(status, _health_status, _chain_type), do: status

  defp maybe_add_deposits_and_withdrawals(status, health_status, chain_type)
       when chain_type in @chain_types_with_messages do
    status
    |> Map.put(:deposits, deposits_indexing_status(health_status))
    |> Map.put(:withdrawals, withdrawals_indexing_status(health_status))
  end

  defp maybe_add_deposits_and_withdrawals(status, _health_status, _chain_type), do: status

  defp maybe_put_batches(health_status, indexing_status, chain_type) when chain_type in @rollups do
    # todo: also factor batches.healthy into the top-level `healthy` when the "latest block"
    # metric starts to remain non-empty all the time
    put_in(health_status, [:metadata, :batches], indexing_status.batches)
  end

  defp maybe_put_batches(health_status, _indexing_status, _chain_type), do: health_status

  defp maybe_put_deposits_and_withdrawals(health_status, indexing_status, chain_type)
       when chain_type in @chain_types_with_messages do
    health_status
    |> put_in([:metadata, :deposits], indexing_status.deposits)
    |> put_in([:metadata, :withdrawals], indexing_status.withdrawals)
  end

  defp maybe_put_deposits_and_withdrawals(health_status, _indexing_status, _chain_type), do: health_status

  defp blocks_indexing_status(health_status) do
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

  defp deposits_indexing_status(health_status) do
    latest_deposit_timestamp_from_db =
      if is_nil(health_status[:health_latest_deposit_timestamp_from_db]) do
        nil
      else
        {:ok, latest_deposit_timestamp_from_db} =
          DateTime.from_unix(Decimal.to_integer(health_status[:health_latest_deposit_timestamp_from_db]))

        latest_deposit_timestamp_from_db
      end

    {healthy?, code, message} =
      case HealthHelper.deposits_indexing_healthy?(health_status) do
        true -> {true, 0, nil}
        other -> other
      end

    base_response =
      %{
        healthy: healthy?,
        latest_deposit: %{
          db: %{
            l1_block_number: to_string(health_status[:health_latest_deposit_l1_block_number_from_db]),
            timestamp: to_string(latest_deposit_timestamp_from_db),
            average_deposit_time: to_string(health_status[:health_latest_deposit_average_time_from_db])
          }
        }
      }

    if healthy? do
      base_response
    else
      Map.put(base_response, :error, error(code, message))
    end
  end

  defp withdrawals_indexing_status(health_status) do
    latest_withdrawal_timestamp_from_db =
      if is_nil(health_status[:health_latest_withdrawal_timestamp_from_db]) do
        nil
      else
        {:ok, latest_withdrawal_timestamp_from_db} =
          DateTime.from_unix(Decimal.to_integer(health_status[:health_latest_withdrawal_timestamp_from_db]))

        latest_withdrawal_timestamp_from_db
      end

    {healthy?, code, message} =
      case HealthHelper.withdrawals_indexing_healthy?(health_status) do
        true -> {true, 0, nil}
        other -> other
      end

    base_response =
      %{
        healthy: healthy?,
        latest_withdrawal: %{
          db: %{
            l2_block_number: to_string(health_status[:health_latest_withdrawal_l2_block_number_from_db]),
            timestamp: to_string(latest_withdrawal_timestamp_from_db),
            average_withdrawal_time: to_string(health_status[:health_latest_withdrawal_average_time_from_db])
          }
        }
      }

    if healthy? do
      base_response
    else
      Map.put(base_response, :error, error(code, message))
    end
  end

  defp error(code, message) do
    %{
      code: code,
      message: message
    }
  end
end
