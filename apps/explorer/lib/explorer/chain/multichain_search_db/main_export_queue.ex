defmodule Explorer.Chain.MultichainSearchDb.MainExportQueue do
  @moduledoc """
  Tracks data pending for export to the Multichain Service database.
  """

  use Explorer.Schema
  import Ecto.Query
  alias Explorer.{Chain, Repo}
  alias Explorer.Chain.Block.Range

  @required_attrs ~w(hash hash_type)a

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
    |> cast(attrs, @required_attrs)
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
    |> Chain.add_fetcher_limit(limited?)
    |> Repo.stream_reduce(initial, reducer)
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
  Returns an Ecto query that defines the default conflict resolution strategy for the
  `multichain_search_db_main_export_queue` table. On conflict, it increments the `retries_number`
  (by using the value from `EXCLUDED.retries_number` or 0 if not present) and updates the
  `updated_at` field to the greatest value between the current and the new timestamp.

  This is typically used in upsert operations to ensure retry counts are tracked and
  timestamps are properly updated.
  """
  @spec default_on_conflict :: Ecto.Query.t()
  def default_on_conflict do
    from(
      multichain_search_db_main_export_queue in __MODULE__,
      update: [
        set: [
          retries_number: fragment("COALESCE(EXCLUDED.retries_number, 0) + 1"),
          updated_at: fragment("GREATEST(?, EXCLUDED.updated_at)", multichain_search_db_main_export_queue.updated_at)
        ]
      ]
    )
  end
end
