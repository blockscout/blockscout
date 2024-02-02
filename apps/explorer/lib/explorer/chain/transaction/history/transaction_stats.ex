defmodule Explorer.Chain.Transaction.History.TransactionStats do
  @moduledoc """
  Represents daily transaction numbers.
  """

  import Ecto.Query, only: [from: 2]

  use Explorer.Schema

  alias Explorer.Chain

  @derive {Jason.Encoder,
           except: [
             :__meta__
           ]}

  schema "transaction_stats" do
    field(:date, :date)
    field(:number_of_transactions, :integer)
    field(:gas_used, :decimal)
    field(:total_fee, :decimal)
  end

  @typedoc """
  The recorded values of the number of transactions for a single day.
   * `:date` - The date in UTC.
   * `:number_of_transactions` - Number of transactions processed by the vm for a given date.
   * `:gas_used` - Gas used in transactions per single day
   * `:total_fee` - Total fee paid to validators from success transactions per single day
  """
  @type t :: %__MODULE__{
          date: Date.t(),
          number_of_transactions: integer(),
          gas_used: non_neg_integer(),
          total_fee: non_neg_integer()
        }

  @spec by_date_range(Date.t(), Date.t()) :: [__MODULE__]
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
