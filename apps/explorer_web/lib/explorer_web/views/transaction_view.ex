defmodule ExplorerWeb.TransactionView do
  use ExplorerWeb, :view

  alias Cldr.Number
  alias Explorer.Chain
  alias Explorer.Chain.{InternalTransaction, Transaction, Wei}
  alias Explorer.ExchangeRates.Token
  alias ExplorerWeb.{AddressView, BlockView}
  alias ExplorerWeb.ExchangeRates.USD

  import ExplorerWeb.Gettext

  def contract_creation?(%Transaction{created_contract_address_hash: nil}), do: false
  def contract_creation?(_), do: true

  def contract?(%Transaction{from_address: from_address, to_address: to_address}) do
    AddressView.contract?(from_address) || AddressView.contract?(to_address)
  end

  def tile_class(%Transaction{} = transaction) do
    cond do
      contract_creation?(transaction) -> "tile-type-contract-creation"
      contract?(transaction) -> "tile-type-contract"
      true -> "tile-type-transaction"
    end
  end

  def transaction_display_type(%Transaction{} = transaction) do
    cond do
      contract_creation?(transaction) -> gettext("Contract Creation")
      contract?(transaction) -> gettext("Contract")
      true -> gettext("Transaction")
    end
  end

  # This is the address to be shown in the to field
  def display_to_address(%Transaction{to_address_hash: nil, created_contract_address_hash: address_hash}),
    do: [address: nil, address_hash: address_hash]

  def display_to_address(%Transaction{to_address: address}), do: [address: address]

  def confirmations(%Transaction{block: block}, named_arguments) when is_list(named_arguments) do
    case block do
      nil -> 0
      _ -> Chain.confirmations(block, named_arguments)
    end
  end

  def gas_used(%Transaction{gas_used: nil}), do: gettext("Pending")

  def gas_used(%Transaction{gas_used: gas_used}) do
    Number.to_string!(gas_used)
  end

  def formatted_fee(%Transaction{} = transaction, opts) do
    transaction
    |> Chain.fee(:wei)
    |> fee_to_currency(opts)
    |> case do
      {_, nil} -> nil
      {:actual, value} -> value
      {:maximum, value} -> "<= " <> value
    end
  end

  def qr_code(%Transaction{hash: hash}) do
    hash
    |> to_string()
    |> QRCode.to_png()
    |> Base.encode64()
  end

  defp fee_to_currency({fee_type, fee}, denomination: denomination) do
    {fee_type, format_wei_value(Wei.from(fee, :wei), denomination)}
  end

  defp fee_to_currency({fee_type, fee}, exchange_rate: %Token{} = exchange_rate) do
    formatted =
      fee
      |> Wei.from(:wei)
      |> USD.from(exchange_rate)
      |> format_usd_value()

    {fee_type, formatted}
  end

  def format_gas_limit(gas) do
    Number.to_string!(gas)
  end

  def formatted_usd_value(%Transaction{value: nil}, _token), do: nil

  def formatted_usd_value(%Transaction{value: value}, token) do
    format_usd_value(USD.from(value, token))
  end

  defdelegate formatted_timestamp(block), to: BlockView

  defguardp is_transaction_type(mod) when mod in [InternalTransaction, Transaction]

  def gas(%type{gas: gas}) when is_transaction_type(type) do
    Cldr.Number.to_string!(gas)
  end

  @doc """
  Converts a transaction's gas price to a displayable value.
  """
  def gas_price(%Transaction{gas_price: gas_price}, unit) when unit in ~w(wei gwei ether)a do
    format_wei_value(gas_price, unit)
  end

  def hash(%Transaction{hash: hash}) do
    to_string(hash)
  end

  def status(transaction) do
    Chain.transaction_to_status(transaction)
  end

  def formatted_status(transaction) do
    transaction
    |> Chain.transaction_to_status()
    |> case do
      :failed -> gettext("Failed")
      :out_of_gas -> gettext("Out of Gas")
      :pending -> gettext("Pending")
      :success -> gettext("Success")
    end
  end

  @doc """
  Converts a transaction's Wei value to Ether and returns a formatted display value.

  ## Options

  * `:include_label` - Boolean. Defaults to true. Flag for displaying unit with value.
  """
  def value(%mod{value: value}, opts \\ []) when is_transaction_type(mod) do
    include_label? = Keyword.get(opts, :include_label, true)
    format_wei_value(value, :ether, include_unit_label: include_label?)
  end
end
