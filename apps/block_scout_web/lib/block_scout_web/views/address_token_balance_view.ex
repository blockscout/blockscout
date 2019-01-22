defmodule BlockScoutWeb.AddressTokenBalanceView do
  use BlockScoutWeb, :view

  alias BlockScoutWeb.CurrencyHelpers

  def tokens_count_title(token_balances) do
    ngettext("%{count} token", "%{count} tokens", Enum.count(token_balances))
  end

  def filter_by_type(token_balances, type) do
    Enum.filter(token_balances, &(&1.token.type == type))
  end

  @doc """
  Sorts the given list of tokens in alphabetically order considering nil values in the bottom of
  the list.
  """
  def sort_by_name(token_balances) do
    {unnamed, named} = Enum.split_with(token_balances, &is_nil(&1.token.name))
    Enum.sort_by(named, &String.downcase(&1.token.name)) ++ unnamed
  end

  @doc """
  Return the balance in usd corresponding to this token. Return nil if the usd_value of the token is not present.
  """
  def balance_in_usd(%{token: %{usd_value: nil}}) do
    nil
  end

  def balance_in_usd(token_balance) do
    tokens = CurrencyHelpers.divide_decimals(token_balance.value, token_balance.token.decimals)
    price = token_balance.token.usd_value
    Decimal.mult(tokens, price)
  end
end
