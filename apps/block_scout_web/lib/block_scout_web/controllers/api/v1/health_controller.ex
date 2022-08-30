defmodule BlockScoutWeb.API.V1.HealthController do
  use BlockScoutWeb, :controller

  require APILogger

  alias Explorer.{Chain, Health}

  def health(conn, _) do
    APILogger.log(conn)

    with {:ok, number, timestamp} <- Chain.last_db_block_status(),
         {:ok, cache_number, cache_timestamp} <- Chain.last_cache_block_status() do
      send_resp(conn, :ok, result(number, timestamp, cache_number, cache_timestamp))
    else
      status -> send_resp(conn, :internal_server_error, error(status))
    end
  end

  def alive?(conn, _) do
    health_response(conn, Health.alive?())
  end

  defp health_response(conn, true) do
    conn
    |> send_resp(200, "OK")
    |> halt()
  end

  defp health_response(conn, false) do
    conn
    |> send_resp(503, "Service Unavailable")
    |> halt()
  end

  def result(number, timestamp, cache_number, cache_timestamp) do
    %{
      "healthy" => true,
      "data" => %{
        "latest_block_number" => to_string(number),
        "latest_block_inserted_at" => to_string(timestamp),
        "cache_latest_block_number" => to_string(cache_number),
        "cache_latest_block_inserted_at" => to_string(cache_timestamp)
      }
    }
    |> Jason.encode!()
  end

  def error({:error, :no_blocks}) do
    %{
      "healthy" => false,
      "error_code" => 5002,
      "error_title" => "no blocks in db",
      "error_description" => "There are no blocks in the DB"
    }
    |> Jason.encode!()
  end

  def error({:error, number, timestamp}) do
    %{
      "healthy" => false,
      "error_code" => 5001,
      "error_title" => "blocks fetching is stuck",
      "error_description" =>
        "There are no new blocks in the DB for the last 5 mins. Check the healthiness of Ethereum archive node or the Blockscout DB instance",
      "data" => %{
        "latest_block_number" => to_string(number),
        "latest_block_inserted_at" => to_string(timestamp)
      }
    }
    |> Jason.encode!()
  end
end
