defmodule BlockScoutWeb.API.V1.GasPriceOracleController do
  use BlockScoutWeb, :controller

  alias Explorer.Chain

  require Logger

  @num_of_blocks (if System.get_env("GAS_PRICE_ORACLE_NUM_OF_BLOCKS") do
                    case Integer.parse(System.get_env("GAS_PRICE_ORACLE_NUM_OF_BLOCKS")) do
                      {integer, ""} -> integer
                      _ -> nil
                    end
                  end)

  @safelow (if System.get_env("GAS_PRICE_ORACLE_SAFELOW_PERCENTILE") do
              case Integer.parse(System.get_env("GAS_PRICE_ORACLE_SAFELOW_PERCENTILE")) do
                {integer, ""} -> integer
                _ -> nil
              end
            end)

  @average (if System.get_env("GAS_PRICE_ORACLE_AVERAGE_PERCENTILE") do
              case Integer.parse(System.get_env("GAS_PRICE_ORACLE_AVERAGE_PERCENTILE")) do
                {integer, ""} -> integer
                _ -> nil
              end
            end)

  @fast (if System.get_env("GAS_PRICE_ORACLE_FAST_PERCENTILE") do
           case Integer.parse(System.get_env("GAS_PRICE_ORACLE_FAST_PERCENTILE")) do
             {integer, ""} -> integer
             _ -> nil
           end
         end)

  def gas_price_oracle(conn, _) do
    case Chain.get_average_gas_price(@num_of_blocks, @safelow, @average, @fast) do
      {:ok, gas_prices} -> send_resp(conn, :ok, result(gas_prices))
      status -> send_resp(conn, :internal_server_error, error(status))
    end
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
