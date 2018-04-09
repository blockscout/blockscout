defmodule ExplorerWeb.WeiConverter do
  @moduledoc """
  Utility module for conversion of wei to other units
  """

  @wei_per_ether 1_000_000_000_000_000_000
  @wei_per_gwei 1_000_000_000

  @spec to_ether(Decimal.t()) :: Decimal.t()
  def to_ether(wei) do
    wei
    |> Decimal.div(Decimal.new(@wei_per_ether))
  end

  @spec to_gwei(Decimal.t()) :: Decimal.t()
  def to_gwei(wei) do
    wei
    |> Decimal.div(Decimal.new(@wei_per_gwei))
  end
end
