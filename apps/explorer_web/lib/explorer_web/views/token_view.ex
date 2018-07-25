defmodule ExplorerWeb.TokenView do
  use ExplorerWeb, :view

  def decimals?(nil), do: false
  def decimals?(_), do: true

  def token_name?(nil), do: false
  def token_name?(_), do: true
end
