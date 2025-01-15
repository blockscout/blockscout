defmodule Explorer.Chain.Transaction.History.TransactionStats do
  @moduledoc """
  Represents daily chain performance stats
  """

  import Ecto.Query, only: [from: 2]

  use Explorer.Schema

  alias Explorer.Chain

  @derive {Jason.Encoder,
           except: [
             :__meta__
           ]}

  @typedoc """
  The recorded values of the chain performance stats for a single day.
   * `:date` - The date in UTC.
   * `:number_of_transactions` - Number of transactions processed by the vm for a given date.
   * `:gas_used` - Gas used in transactions per single day
   * `:total_fee` - Total fee paid to validators from success transactions per single day
  """
  typed_schema "transaction_stats" do
    field(:date, :date)
    field(:number_of_transactions, :integer)
    field(:gas_used, :decimal)
    field(:total_fee, :decimal)
  end

  @doc """
    Retrieves transaction statistics within a specified date range.

    This function queries the database for transaction statistics recorded between
    the given earliest and latest dates, inclusive. The results are ordered by
    date in descending order.

    ## Parameters
    - `earliest`: The start date of the range to query (inclusive).
    - `latest`: The end date of the range to query (inclusive).
    - `options`: Optional keyword list of options used to select the repo for the
      query.

    ## Returns
    A list of `Explorer.Chain.Transaction.History.TransactionStats` structs,
    each representing the transaction statistics for a single day within the
    specified range.
  """
  @spec by_date_range(Date.t(), Date.t(), keyword()) :: [__MODULE__]
  def by_date_range(earliest, latest, options \\ []) do
    # Create a query
    query =
      from(stat in __MODULE__,
        where: stat.date >= ^earliest and stat.date <= ^latest,
        order_by: [desc: :date]
      )

    Chain.select_repo(options).all(query)
  end
end
