defmodule ExplorerWeb.TransactionView do
  use ExplorerWeb, :view

  alias Cldr.Number
  alias Explorer.Chain
  alias Explorer.Chain.{Block, InternalTransaction, Transaction, Wei}
  alias Explorer.ExchangeRates.Token
  alias ExplorerWeb.BlockView

  def confirmations(%Transaction{block: block}, named_arguments) when is_list(named_arguments) do
    case block do
      nil -> 0
      _ -> Chain.confirmations(block, named_arguments)
    end
  end

  def cumulative_gas_used(%Transaction{block: block}) do
    case block do
      nil -> gettext("Pending")
      %Block{gas_used: gas_used} -> Number.to_string!(gas_used)
    end
  end

  def formatted_fee(%Transaction{} = transaction, opts) do
    transaction
    |> Chain.fee(:wei)
    |> fee_to_currency(opts)
    |> case do
      {:actual, value} -> value
      {:maximum, value} -> "<= " <> value
      nil -> nil
    end
  end

  defp fee_to_currency({fee_type, fee}, denomination: denomination) do
    {fee_type, format_wei_value(Wei.from(fee, :wei), denomination, fractional_digits: 18)}
  end

  defp fee_to_currency(_, exchange_rate: %Token{usd_value: nil}), do: nil

  defp fee_to_currency({fee_type, fee}, exchange_rate: %Token{usd_value: usd_value}) do
    usd =
      fee
      |> Wei.from(:wei)
      |> Wei.to(:ether)
      |> Decimal.mult(usd_value)

    currency = gettext("USD")
    {fee_type, "$#{usd} #{currency}"}
  end

  def first_seen(%Transaction{inserted_at: inserted_at}) do
    Timex.from_now(inserted_at)
  end

  def format_gas_limit(gas) do
    Number.to_string!(gas)
  end

  def format_usd(_, %Token{usd_value: nil}), do: nil
  def format_usd(nil, _), do: nil

  def format_usd(value, %Token{usd_value: usd_value}) do
    with {:ok, wei} <- Wei.cast(value),
         ether <- Wei.to(wei, :ether),
         usd <- Decimal.mult(ether, usd_value) do
      currency = gettext("USD")
      "$#{usd} #{currency}"
    else
      _ -> "HMMMM"
    end
  end

  def format_usd_transaction_fee(nil, _token), do: nil

  def format_usd_transaction_fee(%Transaction{} = transaction, token) do
    transaction
    |> Chain.fee(:wei)
    |> case do
      {:actual, actual} -> actual
      {:maximum, maximum} -> maximum
    end
    |> format_usd(token)
  end

  def format_usd_value(%Transaction{value: nil}, _token), do: nil

  def format_usd_value(%Transaction{value: value}, token) do
    format_usd(value, token)
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
