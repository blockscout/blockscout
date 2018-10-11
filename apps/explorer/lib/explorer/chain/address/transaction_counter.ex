defmodule Explorer.Chain.Address.TransactionCounter do
  use Explorer.Schema

  alias Explorer.Repo
  alias Explorer.Chain.{Address, Hash}

  @required_fields ~w(address_hash transactions_number)a

  @type t :: %__MODULE__{
          address: %Ecto.Association.NotLoaded{} | Address.t(),
          address_hash: Hash.Address.t(),
          transactions_number: non_neg_integer()
        }

  @primary_key false
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

  def insert_or_update_counter({address_hash, transactions_number}) do
    %__MODULE__{}
    |> changeset(%{address_hash: address_hash, transactions_number: transactions_number})
    |> Repo.insert(
      on_conflict: [
        inc: [transactions_number: transactions_number]
      ],
      conflict_target: :address_hash
    )
  end
end
