defmodule Explorer.Chain.CeloValidator do
    @moduledoc """
    Data type and schema for storing Celo validators. Most of the data about validators is stored in the Celo accounts table.
    """

    require Logger

    use Explorer.Schema

    alias Explorer.Chain.{Hash, Wei, Address}

    @typedoc """
    * `address` - address of the validator.
    * 
    """

    @type t :: %__MODULE__{
        address: Hash.Address.t(),
        group_address_hash: Hash.Address.t(),
    }

    @attrs ~w(
        address group_address_hash score
    )a

    @required_attrs ~w(
        address
    )a

    schema "celo_validator" do

        field(:score, Wei)

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
        celo_validator
      |> cast(attrs, @attrs)
      |> validate_required(@required_attrs)
      |> unique_constraint(:address)
    end

end

