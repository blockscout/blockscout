defmodule Explorer.Counters.LastFetchedCounter do
  @moduledoc """
  Stores last fetched counters.
  """

  alias Explorer.Counters.LastFetchedCounter
  use Explorer.Schema

  import Ecto.Changeset

  @type t :: %LastFetchedCounter{
          counter_type: String.t(),
          value: Decimal.t()
        }

  @primary_key false
  schema "last_fetched_counters" do
    field(:counter_type, :string)
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
