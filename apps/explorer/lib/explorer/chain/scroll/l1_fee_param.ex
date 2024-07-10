defmodule Explorer.Chain.Scroll.L1FeeParam do
  @moduledoc "Models an L1 fee parameter for Scroll."

  use Explorer.Schema

  @required_attrs ~w(block_number tx_index name value)a

  @typedoc """
    * `block_number` - A block number of the transaction where the given parameter was changed.
    * `tx_index` - An index of the transaction (within the block) where the given parameter was changed.
    * `name` - A name of the parameter (can be `overhead` or `scalar`).
    * `value` - A new value of the parameter.
  """
  @primary_key false
  typed_schema "scroll_l1_fee_params" do
    field(:block_number, :integer, primary_key: true)
    field(:tx_index, :integer, primary_key: true)
    field(:name, Ecto.Enum, values: [:overhead, :scalar])
    field(:value, :integer)

    timestamps()
  end

  def changeset(%__MODULE__{} = params, attrs \\ %{}) do
    params
    |> cast(attrs, @required_attrs)
    |> validate_required(@required_attrs)
    |> unique_constraint([:block_number, :tx_index])
  end
end
