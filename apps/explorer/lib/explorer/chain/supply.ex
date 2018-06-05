defmodule Explorer.Chain.Supply do
  @moduledoc """
  Behaviour for API needed to calculate data related to a chain's supply.

  Since each chain may calculate these values differently, each chain will
  likely need to implement their own calculations for the behaviour.
  """

  @doc """
  The current total number of coins minted minus verifiably burned coins.
  """
  @callback total :: non_neg_integer()

  @doc """
  The current number coins in the market for trading.
  """
  @callback circulating :: non_neg_integer()
end
