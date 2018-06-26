defmodule Explorer.Chain.Statistics do
  @moduledoc """
    Represents statistics about the chain.
  """

  import Ecto.Query

  alias Ecto.Adapters.SQL
  alias Explorer.{Chain, PagingOptions, Repo}
  alias Explorer.Chain.{Block, Transaction}
  alias Timex.Duration

  @average_time_query """
    SELECT coalesce(avg(difference), interval '0 seconds')
    FROM (
      SELECT b.timestamp - lag(b.timestamp) over (order by b.timestamp) as difference
      FROM (SELECT * FROM blocks ORDER BY number DESC LIMIT 101) b
      LIMIT 100 OFFSET 1
    ) t
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

  @transaction_velocity_query """
    SELECT count(transactions.inserted_at)
      FROM transactions
      WHERE transactions.inserted_at > NOW() - interval '1 minute'
  """

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
   * `blocks` - the last <= 5 `t:Explorer.Chain.Block.t/0`
   * `lag` - the average time over the last hour between when the block was mined/validated
     (`t:Explorer.Chain.Block.t/0` `timestamp`) and when it was inserted into the databasse
     (`t:Explorer.Chain.Block.t/0` `inserted_at`)
   * `number` - the latest `t:Explorer.Chain.Block.t/0` `number`
     `t:Explorer.Chain.Block.t/0`
   * `timestamp` - when the last `t:Explorer.Chain.Block.t/0` was mined/validated
   * `transaction_velocity` - the number of `t:Explorer.Chain.Block.t/0` mined/validated in the last minute
   * `transactions` - the last <= 5 `t:Explorer.Chain.Transaction.t/0`
  """
  @type t :: %__MODULE__{
          average_time: Duration.t(),
          blocks: [Block.t()],
          lag: Duration.t(),
          number: Block.block_number(),
          timestamp: :calendar.datetime(),
          transaction_velocity: transactions_per_minute(),
          transactions: [Transaction.t()]
        }

  defstruct average_time: %Duration{seconds: 0, megaseconds: 0, microseconds: 0},
            blocks: [],
            lag: %Duration{seconds: 0, megaseconds: 0, microseconds: 0},
            number: -1,
            timestamp: nil,
            transaction_velocity: 0,
            transactions: []

  def fetch do
    blocks =
      from(
        block in Block,
        order_by: [desc: block.number],
        preload: [:miner, :transactions],
        limit: 5
      )

    transactions =
      Chain.recent_collated_transactions(
        necessity_by_association: %{
          block: :required,
          from_address: :required,
          to_address: :optional
        },
        paging_options: %PagingOptions{page_size: 5}
      )

    %__MODULE__{
      average_time: query_duration(@average_time_query),
      blocks: Repo.all(blocks),
      lag: query_duration(@lag_query),
      transaction_velocity: query_value(@transaction_velocity_query),
      transactions: transactions
    }
    |> put_max_numbered_block()
  end

  defp put_max_numbered_block(state) do
    case Chain.max_numbered_block() do
      {:ok, %Block{number: number, timestamp: timestamp}} ->
        %__MODULE__{
          state
          | number: number,
            timestamp: timestamp
        }

      {:error, :not_found} ->
        state
    end
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
