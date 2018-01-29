defmodule Explorer.TransactionForm do
  @moduledoc false

  def build(transaction) do
    transaction
    |> Map.merge(%{
      block_number: transaction |> block_number,
      age: transaction |> block_age,
      formatted_timestamp: transaction |> format_timestamp,
      cumulative_gas_used: transaction |> cumulative_gas_used,
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
end
