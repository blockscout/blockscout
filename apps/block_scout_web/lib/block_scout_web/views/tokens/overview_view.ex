defmodule BlockScoutWeb.Tokens.OverviewView do
  use BlockScoutWeb, :view

  alias Explorer.Chain.Token
  alias BlockScoutWeb.Tokens.TransferView

  @tabs ["token_transfers", "token_holders", "read_contract"]

  def decimals?(%Token{decimals: nil}), do: false
  def decimals?(%Token{decimals: _}), do: true

  def token_name?(%Token{name: nil}), do: false
  def token_name?(%Token{name: _}), do: true

  def total_supply?(%Token{total_supply: nil}), do: false
  def total_supply?(%Token{total_supply: _}), do: true

  @doc """
  Get the current tab name/title from the request path and possible tab names.

  The tabs on mobile are represented by a dropdown list, which has a title. This title is the
  currently selected tab name. This function returns that name, properly gettext'ed.

  The list of possible tab names for this page is repesented by the attribute @tab.

  Raises error if there is no match, so a developer of a new tab must include it in the list.
  """
  def current_tab_name(request_path) do
    @tabs
    |> Enum.filter(&tab_active?(&1, request_path))
    |> tab_name()
  end

  defp tab_name(["token_transfers"]), do: gettext("Token Transfers")
  defp tab_name(["token_holders"]), do: gettext("Token Holders")
  defp tab_name(["read_contract"]), do: gettext("Read Contract")
end
