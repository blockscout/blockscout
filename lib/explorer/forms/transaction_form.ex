defmodule Explorer.TransactionForm do
  @moduledoc false
  alias Explorer.Address
  alias Explorer.Block
  alias Explorer.FromAddress
  alias Explorer.Repo
  alias Explorer.ToAddress
  alias Explorer.Transaction
  import Ecto.Query

  def build(transaction) do
    transaction
    |> Map.merge(%{
      block_number: transaction |> block_number,
      age: transaction |> block_age,
      formatted_timestamp: transaction |> format_timestamp,
      cumulative_gas_used: transaction |> cumulative_gas_used,
      to_address: transaction |> to_address,
      from_address: transaction |> from_address,
      confirmations: transaction |> confirmations,
    })
  end

  def block_number(transaction) do
    transaction.block.number
  end

  def block_age(transaction) do
    transaction.block.timestamp |> Timex.from_now
  end

  def format_timestamp(transaction) do
    transaction.block.timestamp |> Timex.format!("%b-%d-%Y %H:%M:%S %p %Z", :strftime)
  end

  def cumulative_gas_used(transaction) do
    transaction.block.gas_used
  end

  def to_address(transaction) do
    query = from address in Address,
      join: to_address in ToAddress,
        where: to_address.address_id == address.id,
      join: transaction in Transaction,
        where: transaction.id == to_address.transaction_id,
      where: transaction.id == ^transaction.id

    Repo.one(query).hash
  end

  def from_address(transaction) do
    query = from address in Address,
      join: from_address in FromAddress,
        where: from_address.address_id == address.id,
      join: transaction in Transaction,
        where: transaction.id == from_address.transaction_id,
      where: transaction.id == ^transaction.id

    Repo.one(query).hash
  end

  def confirmations(transaction) do
    query = from block in Block, select: max(block.number)
    Repo.one(query) - transaction.block.number
  end
end
