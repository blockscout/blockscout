defmodule Explorer.SkippedBlocks do
  alias Explorer.Fetcher
  alias Explorer.Block
  alias Explorer.Repo
  alias Ecto.Adapters.SQL
  import Ecto.Query

  @moduledoc false

  @query """
  SELECT missing_numbers.number AS missing_number
  FROM generate_series(1, $1) missing_numbers(number)
  LEFT OUTER JOIN blocks ON (blocks.number = missing_numbers.number)
  WHERE blocks.id IS NULL;
  """

  @dialyzer {:nowarn_function, fetch: 0}
  def fetch do
    get_skipped_blocks()
    |> Enum.map(&Integer.to_string/1)
    |> Enum.map(&Fetcher.fetch/1)
  end

  def get_skipped_blocks do
    last_block_number = get_last_block_number()
    SQL.query!(Repo, @query, [last_block_number]).rows
    |> Enum.map(&List.first/1)
  end

  def get_last_block_number do
    block = Block
    |> order_by(desc: :number)
    |> limit(1)
    |> Repo.all
    |> List.first || %{number: 0}
    block.number
  end
end
