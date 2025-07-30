defmodule Explorer.Chain.MultichainSearchDb.MainExportQueue do
  @moduledoc """
  Tracks main blockchain data: block, transaction hashes, addresses with the metadata and block ranges,
  pending for export to the Multichain Service database.
  """

  use Explorer.Schema
  import Ecto.Query
  alias Explorer.Chain.Block.Range
  alias Explorer.Repo

  @required_attrs ~w(hash hash_type)a
  @optional_attrs ~w(block_range retries_number)a
  @allowed_attrs @optional_attrs ++ @required_attrs

  @primary_key false
  typed_schema "multichain_search_db_main_export_queue" do
    field(:hash, :binary, null: false)

    field(:hash_type, Ecto.Enum,
      values: [
        :block,
        :transaction,
        :address
      ],
      null: false
    )

    field(:retries_number, :integer)
    field(:block_range, Range)

    timestamps()
  end

  def changeset(%__MODULE__{} = pending_ops, attrs) do
    pending_ops
    |> cast(attrs, @allowed_attrs)
    |> validate_required(@required_attrs)
  end

  @spec stream_multichain_db_data_batch(
          initial :: accumulator,
          reducer :: (entry :: map(), accumulator -> accumulator),
          limited? :: boolean()
        ) :: {:ok, accumulator}
        when accumulator: term()
  def stream_multichain_db_data_batch(initial, reducer, limited? \\ false)
      when is_function(reducer, 2) do
    __MODULE__
    |> select([export], %{
      hash: export.hash,
      hash_type: export.hash_type,
      block_range: export.block_range
    })
    |> order_by([export], fragment("upper(?) DESC", export.block_range))
    |> add_main_queue_fetcher_limit(limited?)
    |> Repo.stream_reduce(initial, reducer)
  end

  defp add_main_queue_fetcher_limit(query, false), do: query

  defp add_main_queue_fetcher_limit(query, true) do
    main_queue_fetcher_limit =
      Application.get_env(:indexer, Indexer.Fetcher.MultichainSearchDb.MainExportQueue)[:init_limit]

    limit(query, ^main_queue_fetcher_limit)
  end

  @doc """
  Builds a query to retrieve records from the `Explorer.Chain.MultichainSearchDb.MainExportQueue` module
  where the `hash` field matches any of the given `hashes`.

  ## Parameters

    - `hashes`: A list of hash values to filter the records by.

  ## Returns

    - An Ecto query that can be executed to fetch the matching records.
  """
  @spec by_hashes_query([binary()]) :: Ecto.Query.t()
  def by_hashes_query(hashes) do
    __MODULE__
    |> where([export], export.hash in ^hashes)
  end

  @doc """
  Returns an Ecto query that defines the default behavior for handling conflicts
  when inserting into the `multichain_search_db_main_export_queue` table.

  On conflict, this query:
    - Increments the `retries_number` field by 1 (or sets it to 1 if it was `nil`).
    - Sets the `updated_at` field to the greatest value between the current and the excluded `updated_at`.

  This is typically used with `on_conflict` options in Ecto insert operations.
  """
  @spec default_on_conflict :: Ecto.Query.t()
  def default_on_conflict do
    from(
      multichain_search_db_main_export_queue in __MODULE__,
      update: [
        set: [
          retries_number: fragment("COALESCE(?, 0) + 1", multichain_search_db_main_export_queue.retries_number),
          updated_at: fragment("GREATEST(?, EXCLUDED.updated_at)", multichain_search_db_main_export_queue.updated_at)
        ]
      ]
    )
  end
end
