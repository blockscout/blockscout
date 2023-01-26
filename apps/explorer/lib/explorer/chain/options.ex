defmodule Explorer.Chain.Options do
  @moduledoc "Models options."

  use Explorer.Schema

  @required_attrs ~w(name value)a

  @typedoc """
  * `name` - name of the option
  * `value` - value of the option
  """
  @type t :: %__MODULE__{
          name: String.t(),
          value: map()
        }

  @primary_key false
  schema "options" do
    field(:name, :string, primary_key: true)
    field(:value, :map)
    timestamps()
  end

  def changeset(%__MODULE__{} = options, attrs \\ %{}) do
    options
    |> cast(attrs, @required_attrs)
    |> validate_required(@required_attrs)
  end
end
