
defmodule Explorer.Chain.CeloValidator do
    @moduledoc """

    """

    require Logger

    use Explorer.Schema

    alias Explorer.Chain.{Hash, Address}

    @typedoc """
    * `address` - address of the validator.
    * 
    """

    @type t :: %__MODULE__{
        address: Hash.Address.t(),
        group_address_hash: Hash.Address.t(),
    }

    @attrs ~w(
        address group_address_hash
    )a

    @required_attrs ~w(
        address
    )a

    schema "celo_validator" do

        belongs_to(
            :validator_address,
            Address,
            foreign_key: :address,
            references: :hash,
            type: Hash.Address
        )

        belongs_to(
            :group_address,
            Address,
            foreign_key: :group_address_hash,
            references: :hash,
            type: Hash.Address
        )

        timestamps(null: false, type: :utc_datetime_usec)
    end

    def changeset(%__MODULE__{} = celo_validator, attrs) do
        IO.inspect(attrs)
        celo_validator
      |> cast(attrs, @attrs)
      |> validate_required(@required_attrs)
      |> unique_constraint(:address)
    end

end

