defmodule Explorer.Chain.Transaction.History.Historian do
  @moduledoc """
  Implements behaviour Historian which will compile TransactionStats from Block/Transaction data and then save the TransactionStats into the database for later retrevial.
  """
  require Logger
  use Explorer.History.Historian

  alias Explorer.{Chain, Repo}
  alias Explorer.Chain.{Block, Transaction}
  alias Explorer.Chain.Events.Publisher
  alias Explorer.Chain.Transaction.History.TransactionStats
  alias Explorer.History.Process, as: HistoryProcess

  import Ecto.Query, only: [from: 2, subquery: 1]

  @behaviour Historian

  @impl Historian
  def compile_records(num_days, records \\ []) do
    Logger.info("tx/per day chart: collect records for txs per day stats")

    if num_days == 0 do
      Logger.info("tx/per day chart: records collected #{inspect(records)}")
      # base case
      {:ok, records}
    else
      day_to_fetch = Date.add(date_today(), -1 * (num_days - 1))

      earliest = datetime(day_to_fetch, ~T[00:00:00])
      latest = datetime(day_to_fetch, ~T[23:59:59])

      Logger.info("tx/per day chart: earliest date #{DateTime.to_string(earliest)}")

      Logger.info("tx/per day chart: latest date #{DateTime.to_string(latest)}")

      with {:ok, min_block} <- Chain.timestamp_to_block_number(earliest, :before),
           {:ok, max_block} <- Chain.timestamp_to_block_number(latest, :before) do
        Logger.info("tx/per day chart: min/max block numbers [#{min_block}, #{max_block}]")

        all_transactions_query =
          from(
            transaction in Transaction,
            where: transaction.block_number >= ^min_block and transaction.block_number <= ^max_block
          )

        query =
          from(transaction in subquery(all_transactions_query),
            join: block in Block,
            on: transaction.block_hash == block.hash,
            where: block.consensus == true,
            select: transaction
          )

        num_transactions = Repo.aggregate(query, :count, :hash, timeout: :infinity)
        Logger.info("tx/per day chart: num of transactions #{num_transactions}")
        gas_used = Repo.aggregate(query, :sum, :gas_used, timeout: :infinity)
        Logger.info("tx/per day chart: total gas used #{gas_used}")

        total_fee_query =
          from(transaction in subquery(all_transactions_query),
            join: block in Block,
            on: transaction.block_hash == block.hash,
            where: block.consensus == true,
            select: fragment("SUM(? * ?)", transaction.gas_price, transaction.gas_used)
          )

        total_fee = Repo.one(total_fee_query, timeout: :infinity)
        Logger.info("tx/per day chart: total fee #{total_fee}")

        records = [
          %{date: day_to_fetch, number_of_transactions: num_transactions, gas_used: gas_used, total_fee: total_fee}
          | records
        ]

        compile_records(num_days - 1, records)
      else
        _ ->
          records = [%{date: day_to_fetch, number_of_transactions: 0, gas_used: 0, total_fee: 0} | records]
          compile_records(num_days - 1, records)
      end
    end
  end

  @impl Historian
  def save_records(records) do
    Logger.info("tx/per day chart: save records")

    {num_inserted, _} =
      Repo.insert_all(TransactionStats, records, on_conflict: {:replace_all_except, [:id]}, conflict_target: [:date])

    Logger.info("tx/per day chart: number of inserted #{num_inserted}")

    Publisher.broadcast(:transaction_stats)
    num_inserted
  end

  @spec datetime(Date.t(), Time.t()) :: DateTime.t()
  defp datetime(date, time) do
    {_success?, naive_dt} = NaiveDateTime.new(date, time)
    DateTime.from_naive!(naive_dt, "Etc/UTC")
  end

  defp date_today do
    HistoryProcess.config_or_default(:utc_today, Date.utc_today(), __MODULE__)
  end
end
