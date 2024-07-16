defmodule Explorer.Chain.Supply do
  @moduledoc """
  Behaviour for API needed to calculate data related to a chain's supply.

  Since each chain may calculate these values differently, each chain will
  likely need to implement their own calculations for the behaviour.
  """

  @doc """
  The current total number of coins minted minus verifiably burnt coins.
  """
  @callback total :: non_neg_integer() | %Decimal{sign: 1}

  @doc """
  The current number coins in the market for trading.
  """
  @callback circulating :: non_neg_integer() | %Decimal{sign: 1}

  @doc """
  A map of total supplies per day, optional.
  """
  @callback supply_for_days(days_count :: integer) :: {:ok, term} | {:error, term} | :ok

  defmacro __using__(_opts) do
    quote do
      @behaviour Explorer.Chain.Supply
      def supply_for_days(_days_count), do: :ok

      defoverridable supply_for_days: 1
    end
  end
end
