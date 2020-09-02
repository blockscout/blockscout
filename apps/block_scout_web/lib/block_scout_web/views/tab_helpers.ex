defmodule BlockScoutWeb.TabHelpers do
  @moduledoc """
  Helper functions for dealing with tabs, which are very common between pages.
  """

  @doc """
  Get the current status of a tab by its name and the request path.

  A tab is considered active if its name responds true to active?/2.

  * returns the string "active" if the tab active.
  * returns nil if the tab is not active.

  ## Examples

  iex> BlockScoutWeb.TabHelpers.tab_status("token", "/page/0xSom3tH1ng/token")
  "active"

  iex> BlockScoutWeb.TabHelpers.tab_status("token", "/page/0xSom3tH1ng/token_transfer")
  nil
  """
  def tab_status(tab_name, request_path) do
    if tab_active?(tab_name, request_path) do
      "active"
    end
  end

  @doc """
  Check if the given tab is the current tab given the request path.

  It is considered active if there is a substring that exactly matches the tab name in the path.

  * returns true if the tab name is in the path.
  * returns nil if the tab name is not in the path.

  ## Examples

  iex> BlockScoutWeb.TabHelpers.tab_active?("token", "/page/0xSom3tH1ng/token")
  true

  iex> BlockScoutWeb.TabHelpers.tab_active?("token", "/page/0xSom3tH1ng/token_transfer")
  false
  """
  def tab_active?(tab_name, request_path) do
    String.match?(request_path, ~r/\/\b#{tab_name}\b/)
  end
end
