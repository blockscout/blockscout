defmodule BlockScoutWeb.API.V1.GasPriceOracleController do
  use BlockScoutWeb, :controller

  alias Explorer.Chain.Cache.GasPriceOracle

  require Logger

  def gas_price_oracle(conn, _) do
    case GasPriceOracle.get_gas_prices() do
      {:ok, gas_prices} ->
        send_with_content_type(conn, :ok, result(gas_prices))

      nil ->
        empty_gas_prices = %{
          "slow" => nil,
          "average" => nil,
          "fast" => nil
        }

        send_with_content_type(conn, :internal_server_error, result(empty_gas_prices))

      status ->
        send_with_content_type(conn, :internal_server_error, error(status))
    end
  end

  defp send_with_content_type(conn, status, result) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(status, result)
  end

  def result(gas_prices) do
    gas_prices
    |> Jason.encode!()
  end

  def error({:error, error}) do
    Logger.error(fn -> ["Something went wrong while estimates gas prices in the gas price oracle: ", inspect(error)] end)

    %{
      "error_code" => 6001,
      "error_title" => "Error",
      "error_description" => "Internal server error"
    }
    |> Jason.encode!()
  end
end
