defmodule BlockScoutWeb.Tokens.HolderView do
  use BlockScoutWeb, :view

  alias BlockScoutWeb.Tokens.{OverviewView, TokenView}
  alias Explorer.Chain.{Token}

  @doc """
  Calculates the percentage of the value from the given total supply.

  ## Examples

    iex> value = Decimal.new(200)
    iex> total_supply = Decimal.new(1000)
    iex> BlockScoutWeb.Tokens.HolderView.total_supply_percentage(value, total_supply)
    "20.0000%"

  """
  def total_supply_percentage(value, total_supply) do
    result =
      value
      |> Decimal.div(total_supply)
      |> Decimal.mult(100)
      |> Decimal.round(4)
      |> Decimal.to_string()

    result <> "%"
  end

  @doc """
  Formats the token balance value according to the Token's type.

  ## Examples

    iex> token = build(:token, type: "ERC-20", decimals: 2)
    iex> BlockScoutWeb.Tokens.HolderView.format_token_balance_value(100000, token)
    "1,000"

    iex> token = build(:token, type: "ERC-721")
    iex> BlockScoutWeb.Tokens.HolderView.format_token_balance_value(1, token)
    1

  """
  def format_token_balance_value(value, %Token{type: "ERC-20", decimals: decimals}) do
    format_according_to_decimals(value, decimals)
  end

  def format_token_balance_value(value, _token) do
    value
  end
end
