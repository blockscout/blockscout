defmodule Explorer.Chain.Transaction.History.Historian do
  @moduledoc """
  Implements behaviour Historian which will compile TransactionStats from Block/Transaction data and then save the TransactionStats into the database for later retrevial.
  """
  use Explorer.History.Historian

  alias Explorer.Chain.{Block, Transaction}
  alias Explorer.Chain.Events.Publisher
  alias Explorer.Chain.Transaction.History.TransactionStats
  alias Explorer.History.Process, as: HistoryProcess
  alias Explorer.Repo

  import Ecto.Query, only: [from: 2]

  @behaviour Historian

  @impl Historian
  def compile_records(num_days, records \\ []) do
    if num_days == 0 do
      # base case
      {:ok, records}
    else
      day_to_fetch = Date.add(date_today(), -1 * (num_days - 1))

      earliest = datetime(day_to_fetch, ~T[00:00:00])
      latest = datetime(day_to_fetch, ~T[23:59:59])

      query =
        from(block in Block,
          where: block.timestamp >= ^earliest and block.timestamp <= ^latest,
          join: transaction in Transaction,
          on: block.hash == transaction.block_hash
        )

      num_transactions = Repo.aggregate(query, :count, :hash)
      records = [%{date: day_to_fetch, number_of_transactions: num_transactions} | records]
      compile_records(num_days - 1, records)
    end
  end

  @impl Historian
  def save_records(records) do
    {num_inserted, _} =
      Repo.insert_all(TransactionStats, records, on_conflict: {:replace_all_except, [:id]}, conflict_target: [:date])

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
