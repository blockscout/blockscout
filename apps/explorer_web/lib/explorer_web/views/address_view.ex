defmodule ExplorerWeb.AddressView do
  use ExplorerWeb, :view

  alias Explorer.Chain.{Address, Wei}
  alias Explorer.ExchangeRates.Token
  alias ExplorerWeb.ExchangeRates.USD

  @dialyzer :no_match

  def balance(%Address{fetched_balance: nil}), do: ""

  @doc """
  Returns a formatted address balance and includes the unit.
  """
  def balance(%Address{fetched_balance: balance}) do
    format_wei_value(balance, :ether, fractional_digits: 18)
  end

  def formatted_usd(%Address{fetched_balance: nil}, _), do: nil

  def formatted_usd(%Address{fetched_balance: balance}, %Token{} = exchange_rate) do
    case Wei.cast(balance) do
      {:ok, wei} ->
        wei
        |> USD.from(exchange_rate)
        |> format_usd_value()

      _ ->
        nil
    end
  end

  def hash(%Address{hash: hash}) do
    to_string(hash)
  end
end
