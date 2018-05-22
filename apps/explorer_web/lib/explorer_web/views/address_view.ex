defmodule ExplorerWeb.AddressView do
  use ExplorerWeb, :view

  alias Explorer.Chain.Address

  @dialyzer :no_match

  def balance(%Address{fetched_balance: nil}), do: ""

  @doc """
  Returns a formatted address balance and includes the unit.
  """
  def balance(%Address{fetched_balance: balance}) do
    format_wei_value(balance, :ether, fractional_digits: 18)
  end

  def hash(%Address{hash: hash}) do
    to_string(hash)
  end
end
