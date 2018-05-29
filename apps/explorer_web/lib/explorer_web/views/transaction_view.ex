defmodule ExplorerWeb.TransactionView do
  use ExplorerWeb, :view

  alias Cldr.Number
  alias Explorer.Chain
  alias Explorer.Chain.{InternalTransaction, Transaction, Wei}
  alias Explorer.ExchangeRates.Token
  alias ExplorerWeb.BlockView
  alias ExplorerWeb.ExchangeRates.USD

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

  def first_seen(%Transaction{inserted_at: inserted_at}) do
    Timex.from_now(inserted_at)
  end

  def format_gas_limit(gas) do
    Number.to_string!(gas)
  end

  def formatted_usd_value(%Transaction{value: nil}, _token), do: nil

  def formatted_usd_value(%Transaction{value: value}, token) do
    format_usd_value(USD.from(value, token))
  end

  def formatted_age(%Transaction{block: block}) do
    case block do
      nil -> gettext("Pending")
      _ -> "#{BlockView.age(block)} (#{BlockView.formatted_timestamp(block)})"
    end
  end

  def formatted_timestamp(%Transaction{block: block}) do
    case block do
      nil -> gettext("Pending")
      _ -> BlockView.formatted_timestamp(block)
    end
  end

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

  def last_seen(%Transaction{updated_at: updated_at}) do
    Timex.from_now(updated_at)
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
