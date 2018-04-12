defmodule Explorer.InternalTransaction do
  @moduledoc "Models internal transactions."

  use Explorer.Schema

  alias Explorer.InternalTransaction
  alias Explorer.Transaction
  alias Explorer.Address

  schema "internal_transactions" do
    belongs_to(:transaction, Transaction)
    belongs_to(:from_address, Address)
    belongs_to(:to_address, Address)
    field(:index, :integer)
    field(:call_type, :string)
    field(:trace_address, {:array, :integer})
    field(:value, :decimal)
    field(:gas, :decimal)
    field(:gas_used, :decimal)
    field(:input, :string)
    field(:output, :string)
    timestamps()
  end

  @required_attrs ~w(index call_type trace_address value gas gas_used
    transaction_id from_address_id to_address_id)a
  @optional_attrs ~w(input output)

  def changeset(%InternalTransaction{} = internal_transaction, attrs \\ %{}) do
    internal_transaction
    |> cast(attrs, @required_attrs ++ @optional_attrs)
    |> validate_required(@required_attrs)
    |> foreign_key_constraint(:transaction_id)
    |> foreign_key_constraint(:to_address_id)
    |> foreign_key_constraint(:from_address_id)
    |> unique_constraint(:transaction_id, name: :internal_transactions_transaction_id_index_index)
  end

  def null, do: %InternalTransaction{}
end
