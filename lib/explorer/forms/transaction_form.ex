defmodule Explorer.TransactionForm do
  @moduledoc "Format a Block and a Transaction for display."

  import Ecto.Query
  import ExplorerWeb.Gettext

  alias Cldr.Number
  alias Explorer.Block
  alias Explorer.Receipt
  alias Explorer.Repo

  def build(transaction) do
    block = Ecto.assoc_loaded?(transaction.block) && transaction.block || nil
    receipt = Ecto.assoc_loaded?(transaction.receipt) && transaction.receipt
    status = status(transaction, receipt || Receipt.null)

    %{
      block_number: block |> block_number,
      age: block |> block_age,
      formatted_age: block |> format_age,
      formatted_timestamp: block |> format_timestamp,
      cumulative_gas_used: block |> cumulative_gas_used,
      to_address_hash: transaction |> to_address_hash,
      from_address_hash: transaction |> from_address_hash,
      confirmations: block |> confirmations,
      status: status,
      formatted_status: status |> format_status,
      first_seen: transaction |> first_seen,
      last_seen: transaction |> last_seen,
    }
  end

  def build_and_merge(transaction) do
    Map.merge(transaction, build(transaction))
  end

  def block_number(block) do
    block && block.number || ""
  end

  def block_age(block) do
    block && block.timestamp |> Timex.from_now || gettext("Pending")
  end

  def format_age(block) do
    block && "#{block_age(block)} (#{format_timestamp(block)})" || gettext("Pending")
  end

  def format_timestamp(block) do
    block && block.timestamp |> Timex.format!("%b-%d-%Y %H:%M:%S %p %Z", :strftime) || gettext("Pending")
  end

  def cumulative_gas_used(block) do
    block && block.gas_used |> Number.to_string! || gettext("Pending")
  end

  def to_address_hash(transaction) do
    transaction.to_address && transaction.to_address.hash || nil
  end

  def from_address_hash(transaction) do
    transaction.to_address && transaction.from_address.hash || nil
  end

  def confirmations(block) do
    query = from block in Block, select: max(block.number)
    block && Repo.one(query) - block.number || 0
  end

  def status(transaction, receipt) do
    %{
      0 => %{true => :out_of_gas, false => :failed},
      1 => %{true => :success, false => :success}
    }
    |> Map.get(receipt.status, %{true: :pending, false: :pending})
    |> Map.get(receipt.gas_used == transaction.gas)
  end

  def format_status(status) do
    %{
      out_of_gas: gettext("Out of Gas"),
      failed: gettext("Failed"),
      success: gettext("Success"),
      pending: gettext("Pending"),
    } |> Map.fetch!(status)
  end

  def first_seen(transaction) do
    transaction.inserted_at |> Timex.from_now
  end

  def last_seen(transaction) do
    transaction.updated_at |> Timex.from_now
  end
end
