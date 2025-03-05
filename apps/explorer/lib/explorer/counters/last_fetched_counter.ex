defmodule Explorer.Counters.LastFetchedCounter do
  @moduledoc """
  Stores last fetched counters.
  """

  use Explorer.Schema

  import Ecto.Changeset

  alias Explorer.Chain

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

  @spec get_multiple([binary()], Keyword.t()) :: integer() | [Decimal.t()] | nil
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
