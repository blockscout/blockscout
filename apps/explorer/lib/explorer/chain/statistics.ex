defmodule Explorer.Chain.Statistics do
  @moduledoc """
    Represents statistics about the chain.
  """

  import Ecto.Query

  alias Ecto.Adapters.SQL
  alias Explorer.Chain.{Block, Transaction}
  alias Explorer.Repo
  alias Timex.Duration

  # Constants

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
      JOIN blocks ON blocks.id = transactions.block_id
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

  # Types

  @typedoc """
  The number of `t:Explorer.Chain.Block.t/0` mined/validated per minute.
  """
  @type blocks_per_minute :: non_neg_integer()

  @typedoc """
  The number of `t:Explorer.Chain.Transaction.t/0` mined/validated per minute.
  """
  @type transactions_per_minute :: non_neg_integer()

  @typedoc """
  * `average_time` - the average time it took to mine/validate the last <= 100 `t:Explorer.Chain.Block.t/0`
  * `block_velocity` - the number of `t:Explorer.Chain.Block.t/0` mined/validated in the last minute
  * `blocks` - the last <= 5 `t:Explorer.Chain.Block.t/0`
  * `lag` - the average time over the last hour between when the block was mined/validated
      (`t:Explorer.Chain.Block.t/0` `timestamp`) and when it was inserted into the databasse
      (`t:Explorer.Chain.Block.t/0` `inserted_at`)
  * `number` - the latest `t:Explorer.Chain.Block.t/0` `number`
  * `skipped_blocks` - the number of blocks that were mined/validated, but do not exist as `t:Explorer.Chain.Block.t/0`
  * `timestamp` - when the last `t:Explorer.Chain.Block.t/0` was mined/validated
  * `transaction_count` - the number of transactions confirmed in blocks that were mined/validated in the last day
  * `transaction_velocity` - the number of `t:Explorer.Chain.Block.t/0` mined/validated in the last minute
  * `transactions` - the last <= 5 `t:Explorer.Chain.Transaction.t/0`
  """
  @type t :: %__MODULE__{
          average_time: Duration.t(),
          block_velocity: blocks_per_minute(),
          blocks: [Block.t()],
          lag: Duration.t(),
          number: Block.number(),
          skipped_blocks: non_neg_integer(),
          timestamp: :calendar.datetime(),
          transaction_count: non_neg_integer(),
          transaction_velocity: transactions_per_minute(),
          transactions: [Transaction.t()]
        }

  # Struct

  defstruct average_time: %Duration{seconds: 0, megaseconds: 0, microseconds: 0},
            block_velocity: 0,
            blocks: [],
            lag: %Duration{seconds: 0, megaseconds: 0, microseconds: 0},
            number: -1,
            skipped_blocks: 0,
            timestamp: :calendar.universal_time(),
            transaction_count: 0,
            transaction_velocity: 0,
            transactions: []

  # Functions

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

    %__MODULE__{
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
