defmodule BlockScoutWeb.API.V1.HealthController do
  use Phoenix.Controller, namespace: BlockScoutWeb

  import Plug.Conn

  alias Explorer.Chain
  alias Timex.Duration

  @ok_message "OK"

  def health(conn, params) do
    health(conn, params, Application.get_env(:nft_media_handler, :standalone_media_worker?))
  end

  defp health(conn, _params, false) do
    with {:ok, number, timestamp} <- Chain.last_db_block_status(),
         {:ok, cache_number, cache_timestamp} <- Chain.last_cache_block_status() do
      send_resp(conn, :ok, result(number, timestamp, cache_number, cache_timestamp))
    else
      status -> send_resp(conn, :internal_server_error, error(status))
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

  def liveness(conn, _) do
    send_resp(conn, :ok, @ok_message)
  end

  def readiness(conn, _) do
    unless Application.get_env(:nft_media_handler, :standalone_media_worker?) do
      Chain.last_db_block_status()
    end

    send_resp(conn, :ok, @ok_message)
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
    healthy_blocks_period = Application.get_env(:explorer, :healthy_blocks_period)

    healthy_blocks_period_formatted =
      healthy_blocks_period
      |> Duration.from_milliseconds()
      |> Duration.to_minutes()
      |> trunc()

    %{
      "healthy" => false,
      "error_code" => 5001,
      "error_title" => "blocks fetching is stuck",
      "error_description" =>
        "There are no new blocks in the DB for the last #{healthy_blocks_period_formatted} mins. Check the healthiness of Ethereum archive node or the Blockscout DB instance",
      "data" => %{
        "latest_block_number" => to_string(number),
        "latest_block_inserted_at" => to_string(timestamp)
      }
    }
    |> Jason.encode!()
  end
end
