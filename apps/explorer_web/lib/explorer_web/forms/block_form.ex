defmodule ExplorerWeb.BlockForm do
  @moduledoc false
  alias Explorer.Block
  alias Explorer.BlockTransaction
  alias Explorer.Repo
  import Ecto.Query

  def build(block) do
    block
    |> Map.merge(%{
      transactions_count: block |> get_transactions_count,
      age: block |> calculate_age,
      formatted_timestamp: block |> format_timestamp
    })
  end

  def get_transactions_count(block) do
    query =
      from(
        block_transaction in BlockTransaction,
        join: block in Block,
        where: block.id == block_transaction.block_id,
        where: block.id == ^block.id,
        select: count(block_transaction.block_id)
      )

    Repo.one(query)
  end

  def calculate_age(block) do
    block.timestamp |> Timex.from_now()
  end

  def format_timestamp(block) do
    block.timestamp |> Timex.format!("%b-%d-%Y %H:%M:%S %p %Z", :strftime)
  end
end
