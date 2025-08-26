defmodule Explorer.Chain.MultichainSearchDb.CountersExportQueue do
  @moduledoc """
    Tracks counters data, pending for export to the Multichain Service database.
  """

  use Explorer.Schema

  import Ecto.Query

  alias Ecto.Multi
  alias Explorer.Repo

  @required_attrs ~w(timestamp counter_type data)a
  @optional_attrs ~w(retries_number)a
  @allowed_attrs @optional_attrs ++ @required_attrs

  @typedoc """
    * `timestamp` - The timestamp of the counters. The counters in `data` are only relevant at the moment of the timestamp.
    * `counter_type` - The type of the counters in `data`. Currently only `global` type is implemented which includes the following counters:
                       - daily transactions number
                       - total transactions number
                       - total addresses number
    * `data` - The map containing the counters relevant to the timestamp.
    * `retries_number` - A number of retries to send the counters to Multichain service.
                         Equals to `nil` if the counters haven't been sent to the service yet.
  """
  @primary_key false
  typed_schema "multichain_search_db_export_counters_queue" do
    field(:timestamp, :utc_datetime_usec, primary_key: true)

    field(:counter_type, Ecto.Enum,
      values: [:global],
      null: false,
      primary_key: true
    )

    field(:data, :map)
    field(:retries_number, :integer)

    timestamps()
  end

  @doc """
    Validates that the `attrs` are valid.
  """
  @spec changeset(Ecto.Schema.t(), map()) :: Ecto.Schema.t()
  def changeset(%__MODULE__{} = queue, attrs) do
    queue
    |> cast(attrs, @allowed_attrs)
    |> validate_required(@required_attrs)
  end

  @doc """
    Streams a batch of multichain database counter entries that need to be retried for export.

    This function selects specific fields from the export records and applies a reducer function
    to each entry in the stream, accumulating the result.
    Optionally, the stream can be limited based on the `limited?` flag.

    ## Parameters
    - `initial`: The initial accumulator value.
    - `reducer`: A function that takes an entry (as a map) and the current accumulator, returning the updated accumulator.
    - `limited?` (optional): A boolean indicating whether to apply a fetch limit to the stream. Defaults to `false`.

    ## Returns
    - `{:ok, accumulator}`: A tuple containing `:ok` and the final accumulator after processing the stream.
  """
  @spec stream_multichain_db_counters_batch(
          initial :: accumulator,
          reducer :: (entry :: map(), accumulator -> accumulator),
          limited? :: boolean()
        ) :: {:ok, accumulator}
        when accumulator: term()
  def stream_multichain_db_counters_batch(initial, reducer, limited? \\ false) when is_function(reducer, 2) do
    __MODULE__
    |> select([export], %{
      timestamp: export.timestamp,
      counter_type: export.counter_type,
      data: export.data
    })
    |> add_queue_fetcher_limit(limited?)
    |> Repo.stream_reduce(initial, reducer)
  end

  # Limits the SELECT query if needed. The limit is defined in `INDEXER_MULTICHAIN_SEARCH_DB_EXPORT_COUNTERS_QUEUE_INIT_QUERY_LIMIT` env variable.
  #
  # ## Parameters
  # - `query`: The query to add the limit to.
  # - `true or false`: If `true`, add the limit. If `false`, leave the query as it is.
  #
  # ## Returns
  # - The modified query with the limit or the source query without changes.
  @spec add_queue_fetcher_limit(Ecto.Query.t(), boolean()) :: Ecto.Query.t()
  defp add_queue_fetcher_limit(query, false), do: query

  defp add_queue_fetcher_limit(query, true) do
    limit = Application.get_env(:indexer, Indexer.Fetcher.MultichainSearchDb.CountersExportQueue)[:init_limit]
    limit(query, ^limit)
  end

  @doc """
    Constructs DELETE FROM queries for the counter items to be deleted from the queue.

    ## Parameters
    - `queue_items`: A list of items to be deleted from the queue. Each item is identified by its primary key.

    ## Returns
    - An `Ecto.Multi` struct containing the delete operations.
  """
  @spec delete_query([%{:timestamp => DateTime.t(), :counter_type => atom(), optional(:data) => map()}]) :: Multi.t()
  def delete_query(queue_items) do
    queue_items
    |> Enum.reduce(Multi.new(), fn queue_item, multi_acc ->
      Multi.delete_all(
        multi_acc,
        {queue_item.timestamp, queue_item.counter_type},
        from(q in __MODULE__,
          where: q.timestamp == ^queue_item.timestamp and q.counter_type == ^queue_item.counter_type
        )
      )
    end)
  end

  @doc """
    Returns the current number of items in the queue.

    ## Returns
    - The current number of items in the queue.
  """
  @spec queue_size() :: non_neg_integer()
  def queue_size do
    Repo.aggregate(__MODULE__, :count)
  end

  @doc """
    Returns an Ecto query that defines the conflict resolution strategy for the
    `multichain_search_db_export_counters_queue` table. On conflict, it increments the `retries_number`
    (by using the db stored value or 0 if not present) and updates the
    `updated_at` field to the greatest value between the current and the new timestamp.

    This is typically used in upsert operations to ensure retry counts are tracked and
    timestamps are properly updated.
  """
  @spec increase_retries_on_conflict :: Ecto.Query.t()
  def increase_retries_on_conflict do
    from(
      q in __MODULE__,
      update: [
        set: [
          retries_number: fragment("COALESCE(?, 0) + 1", q.retries_number),
          updated_at: fragment("GREATEST(?, EXCLUDED.updated_at)", q.updated_at)
        ]
      ]
    )
  end
end
