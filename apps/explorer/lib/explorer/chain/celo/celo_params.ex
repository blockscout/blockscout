defmodule Explorer.Chain.CeloParams do
  @moduledoc """
  Data type and schema for storing Celo network parameters
  """

  require Logger

  use Explorer.Schema

  alias Explorer.Chain.{Hash, Wei}

  @typedoc """
  * `name` - parameter name.
  * 
  """

  @type t :: %__MODULE__{
          name: String.t(),
          number_value: Wei.t(),
          address_value: Hash.Address.t(),
          block_number: Explorer.Chain.Block.block_number()
        }

  @attrs ~w( name number_value address_value block_number )a
  @required_attrs ~w( name )a

  schema "celo_params" do
    field(:name, :string, primary_key: true)
    field(:number_value, Wei)
    field(:address_value, Hash.Address)
    field(:block_number, :integer)

    timestamps(null: false, type: :utc_datetime_usec)
  end

  def changeset(%__MODULE__{} = item, attrs) do
    item
    |> cast(attrs, @attrs)
    |> validate_required(@required_attrs)
    |> unique_constraint(:celo_param_key, name: :celo_param_name_index)
  end
end
