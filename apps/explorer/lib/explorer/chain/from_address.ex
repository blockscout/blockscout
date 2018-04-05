defmodule Explorer.Chain.FromAddress do
  @moduledoc false

  use Explorer.Schema

  alias Explorer.Chain.{Address, Transaction}

  @primary_key false
  schema "from_addresses" do
    belongs_to(:address, Address)
    belongs_to(:transaction, Transaction, primary_key: true)

    timestamps()
  end

  def changeset(%__MODULE__{} = to_address, attrs \\ %{}) do
    to_address
    |> cast(attrs, [:transaction_id, :address_id])
    |> unique_constraint(:transaction_id, name: :from_addresses_transaction_id_index)
  end
end
