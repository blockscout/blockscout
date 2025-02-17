defmodule Explorer.Chain.Transaction.History.Historian do
  @moduledoc """
  Implements behaviour Historian which will compile TransactionStats from Block/Transaction data and then save the TransactionStats into the database for later retrieval.
  """
  require Logger
  use Explorer.History.Historian

  alias Explorer.Chain.{Block, DenormalizationHelper, Transaction}
  alias Explorer.Chain.Block.Reader.General, as: BlockGeneralReader
  alias Explorer.Chain.Events.Publisher
  alias Explorer.Chain.Transaction.History.TransactionStats
  alias Explorer.History.Process, as: HistoryProcess
  alias Explorer.Repo

  import Ecto.Query, only: [from: 2, subquery: 1]

  @behaviour Historian

  @typedoc """
    Chain performance stats for a specific date.
  """
  @type dated_record :: %{
          required(:date) => Date.t(),
          required(:number_of_transactions) => non_neg_integer(),
          required(:gas_used) => non_neg_integer(),
          required(:total_fee) => non_neg_integer()
        }

  # Chain performance stats.
  @typep record :: %{
           number_of_transactions: non_neg_integer(),
           gas_used: non_neg_integer(),
           total_fee: non_neg_integer()
         }

  @impl Historian
  @doc """
    Compiles transaction statistics for a specified number of days.

    This function recursively collects daily transaction statistics, starting
    from the earliest date in the range and moving forward towards the current
    date. The current day's stats are set to zero to avoid presenting incomplete
    data.

    The function attempts to find the appropriate block range for each day and
    compile statistics. If block range determination fails, it employs a fallback
    method or sets the day's stats to zero.

    ## Parameters
    - `num_days`: The number of days to compile records for.
    - `records`: An accumulator for the compiled records. Defaults to an empty list.

    ## Returns
    - `{:ok, [dated_record()]}`: A list of daily transaction statistics on success.
    - `:error`: If an unrecoverable error occurs during compilation.
  """
  @spec compile_records(non_neg_integer(), [dated_record()]) :: {:ok, [dated_record()]} | :error
  def compile_records(num_days, records \\ []) do
    Logger.info("tx/per day chart: collect records for transactions per day stats")

    if num_days == 1 do
      Logger.info("tx/per day chart: records collected #{inspect(records)}")

      # The recourse is finished, and the stats for the current day are set to zero
      # to avoid presenting incomplete data.
      records = [%{date: date_today(), number_of_transactions: 0, gas_used: 0, total_fee: 0} | records]
      {:ok, records}
    else
      # Calculate the date for which the stats are required by subtracting the specified
      # number of days from the current moment,
      day_to_fetch = Date.add(date_today(), -1 * (num_days - 1))

      earliest = datetime(day_to_fetch, ~T[00:00:00])
      latest = datetime(day_to_fetch, ~T[23:59:59])

      Logger.info("tx/per day chart: earliest date #{DateTime.to_string(earliest)}")

      Logger.info("tx/per day chart: latest date #{DateTime.to_string(latest)}")

      from_api = false

      # Try to identify block range for the given day
      with {:ok, min_block} <- BlockGeneralReader.timestamp_to_block_number(earliest, :after, from_api),
           {:ok, max_block} <- BlockGeneralReader.timestamp_to_block_number(latest, :before, from_api) do
        # Collects stats for the block range determining the given day and add
        # the date determining the day to the record.
        record =
          min_block
          |> compile_records_in_range(max_block)
          |> Map.put(:date, day_to_fetch)

        records = [
          record
          | records
        ]

        # By making recursive calls to collect stats for every next day, eventually
        # all stats for the specified number of days will be collected.
        compile_records(num_days - 1, records)
      else
        _ ->
          Logger.info(
            "tx/per day chart: timestamp cannot be converted to min/max blocks, trying to find min/max blocks through a fallback option}"
          )

          # This approach to identify the block range for the given day does not take
          # into account the consensus information in the blocks.
          min_max_block_query =
            from(block in Block,
              where: block.timestamp >= ^earliest and block.timestamp <= ^latest,
              select: {min(block.number), max(block.number)}
            )

          case Repo.one(min_max_block_query, timeout: :infinity) do
            {min_block, max_block} when not is_nil(min_block) and not is_nil(max_block) ->
              # Collects stats for the block range determining the given day and add
              # the date determining the day to the record.
              record =
                min_block
                |> compile_records_in_range(max_block)
                |> Map.put(:date, day_to_fetch)

              records = [
                record
                | records
              ]

              # By making recursive calls to collect stats for every next day, eventually
              # all stats for the specified number of days will be collected.
              compile_records(num_days - 1, records)

            _ ->
              # If it is not possible to identify the block range for the given day,
              # the stats for the day are set to zero.
              Logger.warning("tx/per day chart: failed to get min/max blocks through a fallback option}")
              records = [%{date: day_to_fetch, number_of_transactions: 0, gas_used: 0, total_fee: 0} | records]
              compile_records(num_days - 1, records)
          end
      end
    end
  end

  # Compiles transaction statistics for a given block range.
  #
  # This function aggregates data from transactions within the specified block
  # range, considering only blocks with consensus. It calculates the number of
  # transactions, total gas used, and total transaction fees.
  #
  # The function adapts its query strategy based on whether transaction
  # denormalization has been completed, optimizing for performance in both cases.
  #
  # ## Parameters
  # - `min_block`: The lower bound of the block range (inclusive).
  # - `max_block`: The upper bound of the block range (inclusive).
  #
  # ## Returns
  # A map containing the following keys:
  # - `:number_of_transactions`: The total number of transactions in the range.
  # - `:gas_used`: The total amount of gas used by all transactions in the range.
  # - `:total_fee`: The sum of all transaction fees in the range.
  @spec compile_records_in_range(non_neg_integer(), non_neg_integer()) :: record()
  defp compile_records_in_range(min_block, max_block) do
    Logger.info("tx/per day chart: min/max block numbers [#{min_block}, #{max_block}]")

    # Build a query to receive all transactions in the given block range
    all_transactions_query =
      if DenormalizationHelper.transactions_denormalization_finished?() do
        from(
          transaction in Transaction,
          where: transaction.block_number >= ^min_block and transaction.block_number <= ^max_block,
          where: transaction.block_consensus == true,
          select: transaction
        )
      else
        from(
          transaction in Transaction,
          where: transaction.block_number >= ^min_block and transaction.block_number <= ^max_block
        )
      end

    # Build a query to receive all blocks in the given block range with consensus set to true
    all_blocks_query =
      from(
        block in Block,
        where: block.consensus == true,
        where: block.number >= ^min_block and block.number <= ^max_block,
        select: block.number
      )

    # Not actual if the block_consensus information is already the part of the transaction
    # data. Otherwise, we need to filter out transactions that are in the blocks with consensus
    # set to true.
    query =
      if DenormalizationHelper.transactions_denormalization_finished?() do
        all_transactions_query
      else
        from(transaction in subquery(all_transactions_query),
          join: block in subquery(all_blocks_query),
          on: transaction.block_number == block.number,
          select: transaction
        )
      end

    # Number of transactions in the given block range
    num_transactions = Repo.aggregate(query, :count, :hash, timeout: :infinity)
    Logger.info("tx/per day chart: num of transactions #{num_transactions}")
    # Total gas used in the given block range
    gas_used = Repo.aggregate(query, :sum, :gas_used, timeout: :infinity)
    Logger.info("tx/per day chart: total gas used #{gas_used}")

    # Build a query to receive the total fee in the given block range
    total_fee_query =
      if DenormalizationHelper.transactions_denormalization_finished?() do
        from(transaction in subquery(all_transactions_query),
          select: fragment("SUM(? * ?)", transaction.gas_price, transaction.gas_used)
        )
      else
        from(transaction in subquery(all_transactions_query),
          join: block in Block,
          on: transaction.block_hash == block.hash,
          where: block.consensus == true,
          select: fragment("SUM(? * ?)", transaction.gas_price, transaction.gas_used)
        )
      end

    # Total fee in the given block range
    total_fee = Repo.one(total_fee_query, timeout: :infinity)
    Logger.info("tx/per day chart: total fee #{total_fee}")

    %{number_of_transactions: num_transactions, gas_used: gas_used, total_fee: total_fee}
  end

  @impl Historian
  @doc """
    Saves transaction statistics records to the database.

    This function bulk inserts or updates the provided transaction statistics
    records into the database. After saving the records, it broadcasts
    a `:transaction_stats` event to notify subscribers of the update.

    ## Parameters
    - `records`: A list of `dated_record()` structs containing transaction statistics.

    ## Returns
    - The number of records inserted or updated.
  """
  @spec save_records([dated_record()]) :: non_neg_integer()
  def save_records(records) do
    Logger.info("tx/per day chart: save records")

    {num_inserted, _} =
      Repo.insert_all(TransactionStats, records, on_conflict: {:replace_all_except, [:id]}, conflict_target: [:date])

    Logger.info("tx/per day chart: number of inserted #{num_inserted}")

    Publisher.broadcast(:transaction_stats)
    num_inserted
  end

  # Converts a given date and time to a UTC DateTime
  @spec datetime(Date.t(), Time.t()) :: DateTime.t()
  defp datetime(date, time) do
    {_success?, naive_dt} = NaiveDateTime.new(date, time)
    DateTime.from_naive!(naive_dt, "Etc/UTC")
  end

  # Returns today's date in UTC, using configured value or current date as fallback.
  @spec date_today() :: Date.t()
  defp date_today do
    HistoryProcess.config_or_default(:utc_today, Date.utc_today(), __MODULE__)
  end
end
