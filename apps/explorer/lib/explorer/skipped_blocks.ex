defmodule Explorer.SkippedBlocks do
  @moduledoc """
    Fill in older blocks that were skipped during processing.
  """
  import Ecto.Query, only: [from: 2, limit: 2]

  alias Explorer.Chain.Block
  alias Explorer.Repo.NewRelic, as: Repo

  @missing_number_query "SELECT generate_series(?, 0, -1) AS missing_number"

  def first, do: first(1)

  def first(count) do
    blocks =
      from(
        b in Block,
        right_join: fragment(@missing_number_query, ^latest_block_number()),
        on: b.number == fragment("missing_number"),
        select: fragment("missing_number::text"),
        where: is_nil(b.id),
        limit: ^count
      )

    Repo.all(blocks)
  end

  def latest_block_number do
    block = Repo.one(Block |> Block.latest() |> limit(1)) || Block.null()
    block.number
  end
end
