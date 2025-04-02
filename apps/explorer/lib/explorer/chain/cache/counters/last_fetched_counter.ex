defmodule Explorer.Chain.Cache.Counters.LastFetchedCounter do
  @moduledoc """
  Stores last fetched counters.
  """

  use Explorer.Schema

  alias Explorer.{Chain, Repo}

  import Ecto.Changeset

  @primary_key false
  typed_schema "last_fetched_counters" do
    field(:counter_type, :string, null: false)
    field(:value, :decimal)

    timestamps()
  end

  @doc false
  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, [:counter_type, :value])
    |> validate_required([:counter_type])
  end

  @doc """
  Increments the value of a counter of the specified type by the given value.

  ## Parameters

    - `type` (any): The type of the counter to increment. This is used to filter the counter records.
    - `value` (integer): The amount by which to increment the counter's value.

  ## Returns

    - The result of the `Repo.update_all/3` operation, which includes the number of updated rows.

  ## Notes

    - The query uses `timeout: :infinity` to ensure the operation does not time out.
  """
  @spec increment(binary(), non_neg_integer()) :: {non_neg_integer(), nil}
  def increment(type, value) do
    query =
      from(counter in __MODULE__,
        where: counter.counter_type == ^type
      )

    Repo.update_all(query, [inc: [value: value]], timeout: :infinity)
  end

  @doc """
  Inserts a new record or updates an existing one in the database for the given parameters.

  This function creates a changeset using the provided `params` and attempts to insert it into the database.
  If a conflict occurs on the `:counter_type` field, the existing record is replaced with the new data.

  ## Parameters

    - `params` - A map containing the attributes for the changeset.

  ## Returns

    - On success, returns `{:ok, struct}` where `struct` is the inserted or updated record.
    - On failure, returns `{:error, changeset}` with details about the validation or database error.

  """
  @spec upsert(map()) :: {:ok, __MODULE__.t()} | {:error, Ecto.Changeset.t()}
  def upsert(params) do
    changeset = changeset(%__MODULE__{}, params)

    Repo.insert(changeset,
      on_conflict: :replace_all,
      conflict_target: [:counter_type]
    )
  end

  @doc """
  Fetches the last fetched counter value for the given `type`.

  ## Parameters

    - `type` (any): The type of the counter to fetch.
    - `options` (Keyword, optional): A keyword list of options. Supported options:
      - `:nullable` (boolean): If `true`, returns `nil` when the counter is not found.
        If `false` or not provided, returns `Decimal.new(0)` when the counter is not found.

  ## Returns

    - The value of the counter as a `Decimal` or `nil` if `:nullable` is set to `true` and the counter is not found.
  """
  @spec get(binary(), Keyword.t()) :: Decimal.t() | nil
  def get(type, options \\ []) do
    query =
      from(
        last_fetched_counter in __MODULE__,
        where: last_fetched_counter.counter_type == ^type,
        select: last_fetched_counter.value
      )

    if options[:nullable] do
      Chain.select_repo(options).one(query)
    else
      Chain.select_repo(options).one(query) || Decimal.new(0)
    end
  end

  @doc """
    Fetches multiple last fetched counter values for the given `types`.

    ## Parameters

      - `types` (list of binary): The types of counters to fetch.
      - `options` (Keyword, optional): A keyword list of options passed to `Chain.select_repo()`.

    ## Returns

      - A list of tuples where each tuple contains the counter type and its value: `{counter_type, value}`.
  """
  @spec get_multiple([binary()], Keyword.t()) :: [{binary(), Decimal.t() | nil}]
  def get_multiple(types, options \\ []) do
    query =
      from(
        last_fetched_counter in __MODULE__,
        where: last_fetched_counter.counter_type in ^types,
        select: {last_fetched_counter.counter_type, last_fetched_counter.value}
      )

    Chain.select_repo(options).all(query)
  end
end
