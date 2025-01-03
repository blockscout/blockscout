defmodule Explorer.Chain.Arbitrum.Reader.API.General do
  @moduledoc """
    Provides API-specific functions for querying general Arbitrum data from the database.

    Below These functions that implement functionality not specific to Arbitrum. They are
    candidates for moving to a chain-agnostic module as soon as such need arises. All
    functions in this module enforce the use of replica databases for read
    operations by automatically passing the `api?: true` option to database queries.

    Note: If any function from this module needs to be used outside of API handlers,
    it should be moved to `Explorer.Chain.Arbitrum.Reader.Common` with configurable
    database selection, and a wrapper function should be created in this module
    (see `Explorer.Chain.Arbitrum.Reader.API.Settlement.highest_confirmed_block/0` as an example).
  """

  import Ecto.Query, only: [order_by: 2, where: 3]
  import Explorer.Chain, only: [select_repo: 1]

  alias Explorer.Chain
  alias Explorer.Chain.{Hash, Log}

  @api_true [api?: true]

  @doc """
    Retrieves logs from a transaction that match a specific topic.

    Fetches all logs emitted by the specified transaction that have the given topic
    as their first topic, ordered by log index.

    ## Parameters
    - `transaction_hash`: The hash of the transaction to fetch logs from
    - `topic0`: The first topic to filter logs by

    ## Returns
    - A list of matching logs ordered by index, or empty list if none found
  """
  @spec transaction_to_logs_by_topic0(Hash.Full.t(), binary()) :: [Log.t()]
  def transaction_to_logs_by_topic0(transaction_hash, topic0) do
    Chain.log_with_transactions_query()
    |> where([log, transaction], transaction.hash == ^transaction_hash and log.first_topic == ^topic0)
    |> order_by(asc: :index)
    |> select_repo(@api_true).all()
  end
end
