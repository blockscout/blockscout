defmodule ExplorerWeb.TransactionView do
  use ExplorerWeb, :view

  alias Cldr.Number
  alias Explorer.Chain
  alias Explorer.Chain.{Block, InternalTransaction, Transaction}
  alias ExplorerWeb.BlockView

  # Functions

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

  def gas(%type{gas: gas}) when type in [InternalTransaction, Transaction] do
    Cldr.Number.to_string!(gas)
  end

  def gas_price(transaction, unit) do
    transaction
    |> Chain.gas_price(unit)
    |> Cldr.Number.to_string!()
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

  def value(transaction) do
    transaction
    |> Chain.value(:ether)
    |> Cldr.Number.to_string!()
  end
end
