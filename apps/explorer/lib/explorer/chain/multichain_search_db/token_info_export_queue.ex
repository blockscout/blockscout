defmodule Explorer.Chain.MultichainSearchDb.TokenInfoExportQueue do
  @moduledoc """
  Tracks token data, pending for export to the Multichain Service database.
  """

  use Explorer.Schema

  import Ecto.Query

  alias Explorer.{Chain, Repo}

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
  @spec stream_multichain_db_token_info_batch_to_retry_export(
          initial :: accumulator,
          reducer :: (entry :: map(), accumulator -> accumulator),
          limited? :: boolean()
        ) :: {:ok, accumulator}
        when accumulator: term()
  def stream_multichain_db_token_info_batch_to_retry_export(initial, reducer, limited? \\ false) when is_function(reducer, 2) do
    __MODULE__
    |> select([export], %{
      address_hash: export.address_hash,
      data_type: export.data_type,
      data: export.data
    })
    |> Chain.add_fetcher_limit(limited?)
    |> Repo.stream_reduce(initial, reducer)
  end

  @doc """
  Returns an Ecto query that defines the default conflict resolution strategy for the
  `multichain_search_db_export_token_info_queue` table. On conflict, it increments the `retries_number`
  (by using the value from `EXCLUDED.retries_number` or 0 if not present) and updates the
  `updated_at` field to the greatest value between the current and the new timestamp.

  This is typically used in upsert operations to ensure retry counts are tracked and
  timestamps are properly updated.
  """
  @spec default_on_conflict :: Ecto.Query.t()
  def default_on_conflict do
    from(
      q in __MODULE__,
      update: [
        set: [
          retries_number: fragment("COALESCE(EXCLUDED.retries_number, 0) + 1"),
          updated_at: fragment("GREATEST(?, EXCLUDED.updated_at)", q.updated_at)
        ]
      ]
    )
  end
end
