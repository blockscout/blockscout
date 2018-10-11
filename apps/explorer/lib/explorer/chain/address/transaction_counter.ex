defmodule Explorer.Chain.Address.TransactionCounter do
  use Explorer.Schema

  alias Explorer.Chain.{Address, Hash}

  @required_fields ~w(address_hash transactions_number)a

  @type t :: %__MODULE__{
          address: %Ecto.Association.NotLoaded{} | Address.t(),
          address_hash: Hash.Address.t(),
          transactions_number: non_neg_integer()
        }

  schema "address_transaction_counter" do
    belongs_to(:address, Address, foreign_key: :address_hash, references: :hash, type: Hash.Address)
    field(:transactions_number, :integer)
  end

  def changeset(%__MODULE__{} = transaction_counter, params) do
    transaction_counter
    |> cast(params, @required_fields)
    |> validate_required(@required_fields)
    |> foreign_key_constraint(:address_hash)
  end
end
