defmodule ExplorerWeb.AddressView do
  use ExplorerWeb, :view

  alias Explorer.Chain.{Address, Wei, SmartContract}

  alias Explorer.ExchangeRates.Token
  alias ExplorerWeb.ExchangeRates.USD

  @dialyzer :no_match

  def address_title(%Address{} = address) do
    if contract?(address) do
      gettext("Contract Address")
    else
      gettext("Address")
    end
  end

  @doc """
  Returns a formatted address balance and includes the unit.
  """
  def balance(%Address{fetched_balance: nil}), do: ""

  def balance(%Address{fetched_balance: balance}) do
    format_wei_value(balance, :ether)
  end

  def balance_block_number(%Address{fetched_balance_block_number: nil}), do: ""

  def balance_block_number(%Address{fetched_balance_block_number: fetched_balance_block_number}) do
    to_string(fetched_balance_block_number)
  end

  def contract?(%Address{contract_code: nil}), do: false

  def contract?(%Address{contract_code: _}), do: true

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

  def qr_code(%Address{hash: hash}) do
    hash
    |> to_string()
    |> QRCode.to_png()
    |> Base.encode64()
  end

  def smart_contract_verified?(%Address{smart_contract: %SmartContract{}}), do: true
  def smart_contract_verified?(%Address{smart_contract: nil}), do: false
end
