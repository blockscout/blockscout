defmodule Explorer.Chain do
  @moduledoc """
    Represents statistics about the chain.
  """

  import Ecto.Query

  alias Ecto.Adapters.SQL
  alias Explorer.Block
  alias Explorer.Transaction
  alias Explorer.Repo, as: Repo
  alias Timex.Duration

  defstruct number: -1,
            timestamp: :calendar.universal_time(),
            average_time: %Duration{seconds: 0, megaseconds: 0, microseconds: 0},
            lag: %Duration{seconds: 0, megaseconds: 0, microseconds: 0},
            transaction_count: 0,
            skipped_blocks: 0,
            block_velocity: 0,
            transaction_velocity: 0,
            blocks: [],
            transactions: []

  @average_time_query """
    SELECT coalesce(avg(difference), interval '0 seconds')
    FROM (
      SELECT timestamp - lag(timestamp) over (order by timestamp) as difference
      FROM blocks
      ORDER BY number DESC
      LIMIT 100
    ) t
  """

  @transaction_count_query """
    SELECT count(transactions.id)
      FROM transactions
      JOIN block_transactions ON block_transactions.transaction_id = transactions.id
      JOIN blocks ON blocks.id = block_transactions.block_id
      WHERE blocks.timestamp > NOW() - interval '1 day'
  """

  @skipped_blocks_query """
    SELECT COUNT(missing_number)
      FROM generate_series(0, $1, 1) AS missing_number
      LEFT JOIN blocks ON missing_number = blocks.number
      WHERE blocks.id IS NULL
  """

  @lag_query """
    SELECT coalesce(avg(lag), interval '0 seconds')
    FROM (
      SELECT inserted_at - timestamp AS lag
      FROM blocks
      WHERE blocks.inserted_at > NOW() - interval '1 hour'
        AND blocks.timestamp > NOW() - interval '1 hour'
    ) t
  """

  @block_velocity_query """
    SELECT count(blocks.id)
      FROM blocks
      WHERE blocks.inserted_at > NOW() - interval '1 minute'
  """

  @transaction_velocity_query """
    SELECT count(transactions.id)
      FROM transactions
      WHERE transactions.inserted_at > NOW() - interval '1 minute'
  """

  def fetch do
    blocks =
      from(
        block in Block,
        order_by: [desc: block.number],
        preload: :transactions,
        limit: 5
      )

    transactions =
      from(
        transaction in Transaction,
        join: block in assoc(transaction, :block),
        order_by: [desc: block.number],
        preload: [block: block],
        limit: 5
      )

    last_block = Block |> Block.latest() |> limit(1) |> Repo.one()
    latest_block = last_block || Block.null()

    %Explorer.Chain{
      number: latest_block.number,
      timestamp: latest_block.timestamp,
      average_time: query_duration(@average_time_query),
      transaction_count: query_value(@transaction_count_query),
      skipped_blocks: query_value(@skipped_blocks_query, [latest_block.number]),
      lag: query_duration(@lag_query),
      block_velocity: query_value(@block_velocity_query),
      transaction_velocity: query_value(@transaction_velocity_query),
      blocks: Repo.all(blocks),
      transactions: Repo.all(transactions)
    }
  end

  defp query_value(query, args \\ []) do
    results = SQL.query!(Repo, query, args)
    results.rows |> List.first() |> List.first()
  end

  defp query_duration(query) do
    results = SQL.query!(Repo, query, [])

    {:ok, value} =
      results.rows
      |> List.first()
      |> List.first()
      |> Timex.Ecto.Time.load()

    value
  end
end
