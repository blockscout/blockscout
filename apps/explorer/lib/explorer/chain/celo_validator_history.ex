
defmodule Explorer.Chain.CeloValidatorHistory do
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
        block_number: Explorer.Chain.Block.block_number() | nil,
        index: non_neg_integer(),
    }

    @attrs ~w(
        address block_number index
    )a

    @required_attrs ~w(
        address
    )a
    
    schema "celo_validator_history" do
        field(:block_number, :integer, primary_key: true)
        field(:index, :integer, primary_key: true)

        belongs_to(
            :validator_address,
            Address,
            foreign_key: :address,
            references: :hash,
            type: Hash.Address
        )

        timestamps(null: false, type: :utc_datetime_usec)
    end

    def changeset(%__MODULE__{} = celo_validator_history, attrs) do
        celo_validator_history
      |> cast(attrs, @attrs)
      |> validate_required(@required_attrs)
      |> unique_constraint(:address)
    end

end



