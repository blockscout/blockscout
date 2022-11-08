defmodule Explorer.Celo.Metrics.BlockchainMetrics do
  @moduledoc "A context to collect blockchain metric functions"

  alias Explorer.{Chain, Repo}
  alias Explorer.Chain.PendingBlockOperation
  import Ecto.Query
  alias Ecto.Adapters.SQL

  def pending_blockcount do
    query = from(b in PendingBlockOperation, select: fragment("count(*)"), where: b.fetch_internal_transactions == true)

    query |> Repo.one()
  end

  @doc """
  Fetches count of last n blocks, last block timestamp, last block number and average gas used in the last minute.
  Using a single method to fetch and calculate these values for performance reasons (only 2 queries used).
  """
  @spec metrics_fetcher(integer | nil) ::
          {non_neg_integer, non_neg_integer, non_neg_integer, float}
  def metrics_fetcher(n) do
    last_block_number = Chain.fetch_max_block_number()

    if last_block_number == 0 do
      {0, 0, 0, 0}
    else
      range_start = last_block_number - n + 1

      last_n_blocks_result =
        SQL.query!(
          Repo.Local,
          """
          SELECT
          COUNT(*) AS last_n_blocks_count,
          CAST(EXTRACT(EPOCH FROM (DATE_TRUNC('second', NOW()::timestamp) - MAX(timestamp))) AS INTEGER) AS last_block_age,
          AVG((gas_used/gas_limit)*100) AS average_gas_used
          FROM blocks
          WHERE number BETWEEN $1 AND $2;
          """,
          [range_start, last_block_number]
        )

      {last_n_blocks_count, last_block_age, average_gas_used} =
        case Map.fetch(last_n_blocks_result, :rows) do
          {:ok, [[last_n_blocks_count, last_block_age, average_gas_used]]} ->
            {last_n_blocks_count, last_block_age, average_gas_used}

          _ ->
            0
        end

      {last_n_blocks_count, last_block_age, last_block_number, Decimal.to_float(average_gas_used)}
    end
  end
end
