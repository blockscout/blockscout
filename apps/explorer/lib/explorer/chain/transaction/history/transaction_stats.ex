defmodule Explorer.Chain.Transaction.History.TransactionStats do
  @moduledoc """
  Represents daily transaction numbers.
  """

  import Ecto.Query, only: [from: 2]

  use Explorer.Schema

  alias Explorer.Repo

  schema "transaction_stats" do
    field(:date, :date)
    field(:number_of_transactions, :integer)
  end

  @typedoc """
  The recorded values of the number of transactions for a single day.
   * `:date` - The date in UTC.
   * `:number_of_transactions` - Number of transactions processed by the vm for a given date.
  """
  @type t :: %__MODULE__{
          date: Date.t(),
          number_of_transactions: integer()
        }

  @spec by_date_range(Date.t(), Date.t()) :: [__MODULE__]
  def by_date_range(earliest, latest) do
    # Create a query
    query =
      from(stat in __MODULE__,
        where: stat.date >= ^earliest and stat.date <= ^latest,
        order_by: [desc: :date]
      )

    Repo.all(query)
  end
end
