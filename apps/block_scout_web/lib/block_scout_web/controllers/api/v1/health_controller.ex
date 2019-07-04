defmodule BlockScoutWeb.API.V1.HealthController do
  use BlockScoutWeb, :controller

  alias Explorer.Chain

  def last_block_status(conn, _) do
    status = Chain.last_block_status()

    case status do
      {:ok, _, _} -> send_resp(conn, :ok, result(status))
      _ -> send_resp(conn, :internal_server_error, result(status))
    end
  end

  def result({:ok, number, timestamp}) do
    %{
      "healthy" => true,
      "data" => %{
        "latest_block_number" => to_string(number),
        "latest_block_inserted_at" => to_string(timestamp)
      }
    }
    |> Jason.encode!()
  end

  def result({:error, number, timestamp}) do
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

  def result({:error, :no_blocks}) do
    %{
      "healthy" => false,
      "error_code" => 5002,
      "error_title" => "no blocks in db",
      "error_description" => "There are no blocks in the DB"
    }
    |> Jason.encode!()
  end
end
