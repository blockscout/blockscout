defmodule BlockScoutWeb.AddressContractView do
  use BlockScoutWeb, :view

  def format_smart_contract_abi(abi), do: Poison.encode!(abi, pretty: false)

  @doc """
  Returns the correct format for the optimization text.

    iex> BlockScoutWeb.AddressContractView.format_optimization_text(true)
    "true"

    iex> BlockScoutWeb.AddressContractView.format_optimization_text(false)
    "false"
  """
  def format_optimization_text(true), do: gettext("true")
  def format_optimization_text(false), do: gettext("false")
end
