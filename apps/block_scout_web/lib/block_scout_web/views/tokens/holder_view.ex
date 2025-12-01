defmodule BlockScoutWeb.Tokens.HolderView do
  use BlockScoutWeb, :view

  alias BlockScoutWeb.Tokens.OverviewView
  alias Explorer.Chain.{Address, Token}

  @doc """
  Checks if the total supply percentage must be shown.

  ## Examples

    iex> BlockScoutWeb.Tokens.HolderView.show_total_supply_percentage?(nil)
    false

    iex> BlockScoutWeb.Tokens.HolderView.show_total_supply_percentage?(0)
    false

    iex> BlockScoutWeb.Tokens.HolderView.show_total_supply_percentage?(100)
    true

  """
  def show_total_supply_percentage?(nil), do: false
  def show_total_supply_percentage?(total_supply), do: total_supply > 0

  @doc """
  Calculates the percentage of the value from the given total supply.

  ## Examples

    iex> value = Decimal.new(200)
    iex> total_supply = Decimal.new(1000)
    iex> BlockScoutWeb.Tokens.HolderView.total_supply_percentage(value, total_supply)
    "20.0000%"

  """
  def total_supply_percentage(_, 0), do: "N/A%"

  def total_supply_percentage(_, %Decimal{coef: 0}), do: "N/A%"

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

    iex> token = build(:token, type: "ERC-20", decimals: Decimal.new(2))
    iex> BlockScoutWeb.Tokens.HolderView.format_token_balance_value(100000, nil, token)
    "1,000"

    iex> token = build(:token, type: "ERC-721")
    iex> BlockScoutWeb.Tokens.HolderView.format_token_balance_value(1, nil, token)
    1

  """
  def format_token_balance_value(value, _id, %Token{type: "ERC-20", decimals: decimals}) do
    format_according_to_decimals(value, decimals)
  end

  def format_token_balance_value(value, _id, %Token{type: "ZRC-2", decimals: decimals}) do
    format_according_to_decimals(value, decimals)
  end

  def format_token_balance_value(value, id, %Token{type: "ERC-1155", decimals: decimals}) do
    to_string(format_according_to_decimals(value, decimals)) <> " TokenID " <> to_string(id)
  end

  def format_token_balance_value(value, id, %Token{type: "ERC-404", decimals: decimals}) do
    base = to_string(format_according_to_decimals(value, decimals))

    if id do
      base <> " TokenID " <> to_string(id)
    else
      base
    end
  end

  def format_token_balance_value(_value, _id, %Token{type: "ERC-7984"}) do
    "*confidential*"
  end

  def format_token_balance_value(value, _id, _token) do
    value
  end
end
