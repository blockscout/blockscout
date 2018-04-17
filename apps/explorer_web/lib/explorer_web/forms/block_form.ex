defmodule ExplorerWeb.BlockForm do
  @moduledoc false

  alias Explorer.Chain

  def build(block) do
    block
    |> Map.merge(%{
      age: calculate_age(block),
      formatted_timestamp: format_timestamp(block),
      transactions_count: Chain.block_to_transaction_count(block)
    })
  end

  def calculate_age(block) do
    block.timestamp |> Timex.from_now()
  end

  def format_timestamp(block) do
    block.timestamp |> Timex.format!("%b-%d-%Y %H:%M:%S %p %Z", :strftime)
  end
end
