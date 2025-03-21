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

  @spec increment(binary(), non_neg_integer()) :: {non_neg_integer(), nil}
  def increment(type, value) do
    query =
      from(counter in __MODULE__,
        where: counter.counter_type == ^type
      )

    Repo.update_all(query, [inc: [value: value]], timeout: :infinity)
  end

  @spec upsert(map()) :: {:ok, __MODULE__.t()} | {:error, Ecto.Changeset.t()}
  def upsert(params) do
    changeset = __MODULE__.changeset(%__MODULE__{}, params)

    Repo.insert(changeset,
      on_conflict: :replace_all,
      conflict_target: [:counter_type]
    )
  end

  @spec get(binary(), Keyword.t()) :: integer() | Decimal.t() | nil
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
end
