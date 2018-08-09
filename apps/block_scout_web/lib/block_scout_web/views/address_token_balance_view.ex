defmodule BlockScoutWeb.AddressTokenBalanceView do
  use BlockScoutWeb, :view

  def tokens_count_title(tokens) do
    ngettext("%{count} token", "%{count} tokens", Enum.count(tokens))
  end

  def filter_by_type(tokens, type) do
    Enum.filter(tokens, &(&1.type == type))
  end

  @doc """
  Sorts the given list of tokens in alphabetically order considering nil values in the bottom of
  the list.
  """
  def sort_by_name(tokens) do
    {unnamed, named} = Enum.split_with(tokens, &is_nil(&1.name))
    Enum.sort_by(named, &String.downcase(&1.name)) ++ unnamed
  end
end
