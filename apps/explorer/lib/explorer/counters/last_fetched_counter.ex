defmodule Explorer.Counters.LastFetchedCounter do
  @moduledoc """
  Stores last fetched counters.
  """

  use Explorer.Schema

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
end
