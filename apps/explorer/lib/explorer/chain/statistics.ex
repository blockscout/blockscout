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

  @typedoc """
  The number of `t:Explorer.Chain.Block.t/0` mined/validated per minute.
  """
  @type blocks_per_minute :: non_neg_integer()

  @typedoc """
   * `average_time` - the average time it took to mine/validate the last <= 100 `t:Explorer.Chain.Block.t/0`
   * `blocks` - the last <= 5 `t:Explorer.Chain.Block.t/0`
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
          number: Block.block_number(),
          timestamp: :calendar.datetime(),
          transactions: [Transaction.t()]
        }

  defstruct average_time: %Duration{seconds: 0, megaseconds: 0, microseconds: 0},
            blocks: [],
            number: -1,
            timestamp: nil,
            transactions: []

  def fetch do
    blocks =
      from(
        block in Block,
        order_by: [desc: block.number],
        preload: [:miner, :transactions],
        limit: 4
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
