defmodule Explorer.Chain.CeloWithdrawal do
    @moduledoc """
    Table for storing withdrawal information for Celo Accounts.
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
        timestamp: DateTime.t(),
        amount: Wei.t(),
        index: non_neg_integer(),
    }

    @attrs ~w(
        address timestamp amount index
    )a

    @required_attrs ~w(
        address
    )a

    @primary_key false
    schema "celo_withdrawal" do
        field(:timestamp, :utc_datetime_usec)
        field(:index, :integer, primary_key: true)
        field(:amount, Wei)

        belongs_to(
            :account_address,
            Address,
            foreign_key: :address,
            primary_key: true,
            references: :hash,
            type: Hash.Address
        )

        timestamps(null: false, type: :utc_datetime_usec)
    end

    def changeset(%__MODULE__{} = celo_withdrawal, attrs) do
        celo_withdrawal
      |> cast(attrs, @attrs)
      |> validate_required(@required_attrs)
      |> unique_constraint(:celo_withdrawal_key, name: :celo_withdrawal_account_address_index_index)
    end

end

