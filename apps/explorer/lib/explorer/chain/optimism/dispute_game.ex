defmodule Explorer.Chain.Optimism.DisputeGame do
  @moduledoc "Models a dispute game for Optimism."

  use Explorer.Schema

  alias Explorer.Chain.Hash

  @required_attrs ~w(index game_type address created_at)a
  @optional_attrs ~w(extra_data resolved_at status)a

  @type t :: %__MODULE__{
          index: non_neg_integer(),
          game_type: non_neg_integer(),
          address: Hash.t(),
          extra_data: Hash.t() | nil,
          created_at: DateTime.t(),
          resolved_at: DateTime.t() | nil,
          status: non_neg_integer() | nil
        }

  @primary_key false
  schema "op_dispute_games" do
    field(:index, :integer, primary_key: true)
    field(:game_type, :integer)
    field(:address, Hash.Address)
    field(:extra_data, Hash.Full)
    field(:created_at, :utc_datetime_usec)
    field(:resolved_at, :utc_datetime_usec)
    field(:status, :integer)

    timestamps()
  end

  def changeset(%__MODULE__{} = games, attrs \\ %{}) do
    games
    |> cast(attrs, @required_attrs ++ @optional_attrs)
    |> validate_required(@required_attrs)
    |> unique_constraint(:index)
  end
end
