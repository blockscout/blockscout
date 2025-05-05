defmodule Explorer.Chain.MultichainSearchDbExportRetryQueue do
  @moduledoc """
  Tracks data pending retry for export to the Multichain Service database after an initial failure.
  """

  use Explorer.Schema
  import Ecto.Query
  alias Explorer.{Chain, Repo}

  @required_attrs ~w(id min_block_number max_block_number hash hash_type)a

  @primary_key false
  typed_schema "multichain_search_db_export_retry_queue" do
    field(:hash, :binary, null: true)

    field(:hash_type, Ecto.Enum,
      values: [
        :block,
        :transaction,
        :address
      ],
      null: true
    )

    timestamps()
  end

  def changeset(%__MODULE__{} = pending_ops, attrs) do
    pending_ops
    |> cast(attrs, @required_attrs)
    |> validate_required(@required_attrs)
  end

  @spec stream_multichain_db_data_batch_to_retry_export(
          initial :: accumulator,
          reducer :: (entry :: map(), accumulator -> accumulator),
          limited? :: boolean()
        ) :: {:ok, accumulator}
        when accumulator: term()
  def stream_multichain_db_data_batch_to_retry_export(initial, reducer, limited? \\ false)
      when is_function(reducer, 2) do
    __MODULE__
    |> select([export], %{
      hash: export.hash,
      hash_type: export.hash_type
    })
    |> Chain.add_fetcher_limit(limited?)
    |> Repo.stream_reduce(initial, reducer)
  end

  @doc """
  Builds a query to retrieve records from the `Explorer.Chain.MultichainSearchDbExportRetryQueue` module
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
end
