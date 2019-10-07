defmodule Explorer.Chain.Import.Runner.InternalTransactionsIndexedAtBlocks do
  @moduledoc """
  Bulk updates `internal_transactions_indexed_at` for provided blocks
  """

  require Ecto.Query

  alias Ecto.Multi
  alias Explorer.Chain.Block
  alias Explorer.Chain.Import.Runner

  import Ecto.Query, only: [from: 2]

  @behaviour Runner

  # milliseconds
  @timeout 60_000

  @type imported :: [%{number: Block.block_number()}]

  @impl Runner
  def ecto_schema_module, do: Block

  @impl Runner
  def option_key, do: :internal_transactions_indexed_at_blocks

  @impl Runner
  def imported_table_row do
    %{
      value_type: "[%{number: Explorer.Chain.Block.block_number()}]",
      value_description: "List of block numbers to set `internal_transactions_indexed_at` field for"
    }
  end

  @impl Runner
  def run(multi, changes_list, %{timestamps: timestamps} = options) when is_map(options) do
    transactions_timeout = options[Runner.Transactions.option_key()][:timeout] || Runner.Transactions.timeout()

    update_transactions_options = %{timeout: transactions_timeout, timestamps: timestamps}

    multi
    |> Multi.run(:internal_transactions_indexed_at_blocks, fn repo, _ ->
      update_blocks(repo, changes_list, update_transactions_options)
    end)
  end

  @impl Runner
  def timeout, do: @timeout

  defp update_blocks(_repo, [], %{}), do: {:ok, []}

  defp update_blocks(repo, changes_list, %{
         timeout: timeout,
         timestamps: timestamps
       })
       when is_list(changes_list) do
    block_numbers = Enum.map(changes_list, fn %{number: number} -> number end)

    query =
      from(
        b in Block,
        where: b.number in ^block_numbers and b.consensus,
        # Enforce Block ShareLocks order (see docs: sharelocks.md)
        order_by: [asc: b.hash],
        lock: "FOR UPDATE"
      )

    try do
      {_, result} =
        repo.update_all(
          from(b in Block, join: s in subquery(query), on: b.hash == s.hash, select: b.hash),
          [set: [internal_transactions_indexed_at: timestamps.updated_at]],
          timeout: timeout
        )

      {:ok, result}
    rescue
      postgrex_error in Postgrex.Error ->
        {:error, %{exception: postgrex_error, block_numbers: block_numbers}}
    end
  end
end
