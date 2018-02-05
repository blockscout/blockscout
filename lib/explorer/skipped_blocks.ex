defmodule Explorer.SkippedBlocks do
  alias Explorer.Block
  alias Explorer.Repo
  alias Ecto.Adapters.SQL

  import Ecto.Query, only: [limit: 2]

  @moduledoc false

  @query """
  SELECT missing_numbers.number AS missing_number
  FROM generate_series($1, 0, -1) missing_numbers(number)
  LEFT OUTER JOIN blocks ON (blocks.number = missing_numbers.number)
  WHERE blocks.id IS NULL
  LIMIT $2;
  """

  def first, do: first(1)
  def first(count) do
    SQL.query!(Repo, @query, [latest_block_number(), count]).rows
    |> Enum.map(&List.first/1)
    |> Enum.map(&Integer.to_string/1)
  end

  def latest_block_number do
    (Block |> Block.latest |> limit(1) |> Repo.one || Block.null)
    |> Map.fetch!(:number)
  end
end
