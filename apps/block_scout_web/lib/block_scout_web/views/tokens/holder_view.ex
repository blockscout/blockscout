defmodule BlockScoutWeb.Tokens.HolderView do
  use BlockScoutWeb, :view

  alias BlockScoutWeb.Tokens.OverviewView
  alias Explorer.Chain.Token

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

  def format_token_balance_value(value, id, %Token{type: "ERC-1155", decimals: decimals}) do
    to_string(format_according_to_decimals(value, decimals)) <> " TokenID " <> to_string(id)
  end

  def format_token_balance_value(value, _id, _token) do
    value
  end

  @doc """
  # Finds current balance of ERC-721, ERC-1155 token by finding current_token_balance with max block_number
  """
  def group_current_token_balances(current_token_balances, token_type) do
    if token_type == "ERC-20" do
      current_token_balances
    else
      current_token_balances
      |> Enum.group_by(fn current_token_balance ->
        current_token_balance.address_hash
      end)
      |> Enum.map(fn {_, grouped_address_current_token_balances} ->
        Enum.max_by(grouped_address_current_token_balances, fn %{block_number: block_number} -> block_number end)
      end)
    end
  end
end
