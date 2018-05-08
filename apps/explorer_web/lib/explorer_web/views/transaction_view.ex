defmodule ExplorerWeb.TransactionView do
  use ExplorerWeb, :view

  alias Cldr.Number
  alias Explorer.Chain
  alias Explorer.Chain.{Address, Block, InternalTransaction, Transaction, Wei}
  alias ExplorerWeb.BlockView

  def block(%Transaction{block: block}) do
    case block do
      nil -> gettext("Pending")
      _ -> to_string(block.number)
    end
  end

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

  @doc """
  Calculates the transaction fee and returns a formatted display value.
  """
  def fee(%Transaction{} = transaction) do
    case Chain.fee(transaction, :wei) do
      {:actual, actual} ->
        format_wei_value(Wei.from(actual, :wei), :ether, fractional_digits: 18)

      {:maximum, maximum} ->
        "<= " <> format_wei_value(Wei.from(maximum, :wei), :ether, fractional_digits: 18)
    end
  end

  def first_seen(%Transaction{inserted_at: inserted_at}) do
    Timex.from_now(inserted_at)
  end

  def format_gas_limit(gas) do
    Number.to_string!(gas)
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

  def from_address(%Transaction{from_address: %Address{hash: hash}}) do
    to_string(hash)
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

  def to_address(%Transaction{to_address: to_address}) do
    case to_address do
      nil -> "Contract Creation"
      _ -> to_string(to_address)
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
