defmodule Explorer.TransactionForm do
  @moduledoc "Format a Block and a Transaction for display."

  import Ecto.Query
  import ExplorerWeb.Gettext

  alias Cldr.Number
  alias Explorer.Address
  alias Explorer.Block
  alias Explorer.FromAddress
  alias Explorer.Repo
  alias Explorer.ToAddress
  alias Explorer.Transaction

  def build(transaction) do
    block = transaction.block
    Map.merge(transaction, %{
      block_number: block |> block_number,
      age: block |> block_age,
      formatted_age: block |> format_age,
      formatted_timestamp: block |> format_timestamp,
      cumulative_gas_used: block |> cumulative_gas_used,
      to_address: transaction |> to_address,
      from_address: transaction |> from_address,
      confirmations: block |> confirmations,
      status: transaction |> status,
      first_seen: transaction |> first_seen,
      last_seen: transaction |> last_seen,
    })
  end

  def block_number(block) do
    block && block.number || ""
  end

  def block_age(block) do
    block && block.timestamp |> Timex.from_now || "Pending"
  end

  def format_age(block) do
    if block do
      "#{block_age(block)} (#{format_timestamp(block)})"
    else
      gettext("Pending")
    end
  end

  def format_timestamp(block) do
    block && block.timestamp |> Timex.format!("%b-%d-%Y %H:%M:%S %p %Z", :strftime) || gettext("Pending")
  end

  def cumulative_gas_used(block) do
    block && block.gas_used |> Number.to_string! || gettext("Pending")
  end

  def to_address(transaction) do
    query = from address in Address,
      join: to_address in ToAddress,
        where: to_address.address_id == address.id,
      join: transaction in Transaction,
        where: transaction.id == to_address.transaction_id,
      where: transaction.id == ^transaction.id

    case Repo.one(query) do
      nil ->
        nil
      to_address ->
        to_address.hash
    end
  end

  def from_address(transaction) do
    query = from address in Address,
      join: from_address in FromAddress,
        where: from_address.address_id == address.id,
      join: transaction in Transaction,
        where: transaction.id == from_address.transaction_id,
      where: transaction.id == ^transaction.id

    case Repo.one(query) do
      nil ->
        nil
      from_address ->
        from_address.hash
    end
  end

  def confirmations(block) do
    query = from block in Block, select: max(block.number)
    block && Repo.one(query) - block.number || 0
  end

  def status(transaction) do
    if transaction.block do
      gettext("Success")
    else
      gettext("Pending")
    end
  end

  def first_seen(transaction) do
    transaction.inserted_at |> Timex.from_now
  end

  def last_seen(transaction) do
    transaction.updated_at |> Timex.from_now
  end
end
