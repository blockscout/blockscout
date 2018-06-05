defmodule ExplorerWeb.AddressView do
  use ExplorerWeb, :view

  alias Explorer.Chain.{Address, Wei}
  alias Explorer.Chain.Hash
  alias Explorer.ExchangeRates.Token
  alias ExplorerWeb.ExchangeRates.USD

  @dialyzer :no_match

  def contract?(%Address{contract_code: nil}), do: false
  def contract?(%Address{contract_code: _}), do: true

  def address_title(%Address{} = address) do
    if contract?(address) do
      gettext("Contract Address")
    else
      gettext("Address")
    end
  end

  def balance(%Address{fetched_balance: nil}), do: ""

  @doc """
  Returns a formatted address balance and includes the unit.
  """
  def balance(%Address{fetched_balance: balance}) do
    format_wei_value(balance, :ether)
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

  def hash(%Hash{} = hash) do
    to_string(hash)
  end

  def qr_code(%Address{hash: hash}) do
    hash
    |> to_string()
    |> QRCode.to_png()
    |> Base.encode64()
  end
end
