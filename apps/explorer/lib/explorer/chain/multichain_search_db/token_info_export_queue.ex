defmodule Explorer.Chain.MultichainSearchDb.TokenInfoExportQueue do
  @moduledoc """
    Tracks token data, pending for export to the Multichain Service database.
  """

  use Explorer.Schema

  import Ecto.Query

  alias Explorer.Repo

  @required_attrs ~w(address_hash data_type data)a
  @optional_attrs ~w(retries_number)a
  @allowed_attrs @optional_attrs ++ @required_attrs

  @primary_key false
  typed_schema "multichain_search_db_export_token_info_queue" do
    field(:address_hash, :binary, null: false, primary_key: true)

    field(:data_type, Ecto.Enum,
      values: [
        :metadata,
        :total_supply,
        :counters,
        :market_data
      ],
      null: false,
      primary_key: true
    )

    field(:data, :map)
    field(:retries_number, :integer)

    timestamps()
  end

  def changeset(%__MODULE__{} = queue, attrs) do
    queue
    |> cast(attrs, @allowed_attrs)
    |> validate_required(@required_attrs)
  end

  @doc """
    Streams a batch of multichain database token info entries that need to be retried for export.

    This function selects specific fields from the export records and applies a reducer function to each entry in the stream, accumulating the result. Optionally, the stream can be limited based on the `limited?` flag.

    ## Parameters
    - `initial`: The initial accumulator value.
    - `reducer`: A function that takes an entry (as a map) and the current accumulator, returning the updated accumulator.
    - `limited?` (optional): A boolean indicating whether to apply a fetch limit to the stream. Defaults to `false`.

    ## Returns
    - `{:ok, accumulator}`: A tuple containing `:ok` and the final accumulator after processing the stream.
  """
  @spec stream_multichain_db_token_info_batch(
          initial :: accumulator,
          reducer :: (entry :: map(), accumulator -> accumulator),
          limited? :: boolean()
        ) :: {:ok, accumulator}
        when accumulator: term()
  def stream_multichain_db_token_info_batch(initial, reducer, limited? \\ false) when is_function(reducer, 2) do
    __MODULE__
    |> select([export], %{
      address_hash: export.address_hash,
      data_type: export.data_type,
      data: export.data
    })
    |> add_queue_fetcher_limit(limited?)
    |> Repo.stream_reduce(initial, reducer)
  end

  defp add_queue_fetcher_limit(query, false), do: query

  defp add_queue_fetcher_limit(query, true) do
    limit = Application.get_env(:indexer, Indexer.Fetcher.MultichainSearchDb.TokenInfoExportQueue)[:init_limit]
    limit(query, ^limit)
  end

  @doc """
    Constructs query for DELETE FROM query for the token info item to be deleted from the queue.

    ## Parameters
    - `queue_item`: An item to be deleted from the queue. The item is identified by its primary key.

    ## Returns
    - An `Ecto.Query` struct containing the delete operation.
  """
  @spec delete_query(%{:address_hash => binary(), :data_type => atom(), optional(:data) => map()}) :: Ecto.Query.t()
  def delete_query(queue_item) do
    from(q in __MODULE__,
      where: q.address_hash == ^queue_item.address_hash and q.data_type == ^queue_item.data_type
    )
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
    `multichain_search_db_export_token_info_queue` table. On conflict, it increments the `retries_number`
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
