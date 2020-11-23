defmodule BlockScoutWeb.AddressTokenBalanceView do
  use BlockScoutWeb, :view

  alias Explorer.Chain
  alias Explorer.Counters.AddressTokenUsdSum

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
  Sorts the given list of tokens by usd_value of token in descending order and alphabetically order considering nil values in the bottom of
  the list.
  """
  def sort_by_usd_value_and_name(token_balances) do
    token_balances
    |> Enum.sort(fn token_balance1, token_balance2 ->
      usd_value1 = token_balance1.token.usd_value
      usd_value2 = token_balance2.token.usd_value

      token_name1 = token_balance1.token.name
      token_name2 = token_balance2.token.name

      sort_by_name = sort_2_tokens_by_name(token_name1, token_name2)

      sort_2_tokens_by_value_desc_and_name(token_balance1, token_balance2, usd_value1, usd_value2, sort_by_name)
    end)
  end

  defp sort_2_tokens_by_name(token_name1, token_name2) do
    cond do
      token_name1 && token_name2 ->
        String.downcase(token_name1) <= String.downcase(token_name2)

      token_name1 && is_nil(token_name2) ->
        true

      is_nil(token_name1) && token_name2 ->
        false

      true ->
        true
    end
  end

  defp sort_2_tokens_by_value_desc_and_name(token_balance1, token_balance2, usd_value1, usd_value2, sort_by_name)
       when not is_nil(usd_value1) and not is_nil(usd_value2) do
    case Decimal.cmp(Chain.balance_in_usd(token_balance1), Chain.balance_in_usd(token_balance2)) do
      :gt ->
        true

      :eq ->
        sort_by_name

      :lt ->
        false
    end
  end

  defp sort_2_tokens_by_value_desc_and_name(_token_balance1, _token_balance2, usd_value1, usd_value2, _sort_by_name)
       when not is_nil(usd_value1) and is_nil(usd_value2) do
    true
  end

  defp sort_2_tokens_by_value_desc_and_name(_token_balance1, _token_balance2, usd_value1, usd_value2, _sort_by_name)
       when is_nil(usd_value1) and not is_nil(usd_value2) do
    false
  end

  defp sort_2_tokens_by_value_desc_and_name(_token_balance1, _token_balance2, usd_value1, usd_value2, sort_by_name)
       when is_nil(usd_value1) and is_nil(usd_value2) do
    sort_by_name
  end

  def address_tokens_usd_sum_cache(address, token_balances) do
    AddressTokenUsdSum.fetch(address, token_balances)
  end
end
