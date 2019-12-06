defmodule Explorer.Chain.ExchangeRate do
  @moduledoc """
  Data type and schema for storing exchange rates for tokens.
  """

  use Explorer.Schema

  alias Explorer.Chain.{Address, Hash}

  @typedoc """
  * `address` - address of the validator.
  * 
  """

  @type t :: %__MODULE__{
          token: Hash.Address.t(),
          rate: float
        }

  @attrs ~w( token rate )a

  @required_attrs ~w( token rate )a

  schema "exchange_rates" do
    field(:rate, :float)

    belongs_to(
      :token_address,
      Address,
      foreign_key: :token,
      references: :hash,
      type: Hash.Address
    )

    timestamps(null: false, type: :utc_datetime_usec)
  end

  def changeset(%__MODULE__{} = data, attrs) do
    data
    |> cast(attrs, @attrs)
    |> validate_required(@required_attrs)
    |> unique_constraint(:token)
  end
end
