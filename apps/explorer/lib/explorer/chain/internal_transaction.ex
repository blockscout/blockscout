defmodule Explorer.Chain.InternalTransaction do
  @moduledoc "Models internal transactions."

  use Explorer.Schema

  alias Explorer.Chain.{Address, Transaction}

  schema "internal_transactions" do
    field(:call_type, :string)
    field(:gas, :decimal)
    field(:gas_used, :decimal)
    field(:index, :integer)
    field(:input, :string)
    field(:output, :string)
    field(:trace_address, {:array, :integer})
    field(:value, :decimal)

    timestamps()

    belongs_to(:from_address, Address)
    belongs_to(:to_address, Address)
    belongs_to(:transaction, Transaction)
  end

  @required_attrs ~w(index call_type trace_address value gas gas_used
    transaction_id from_address_id to_address_id)a
  @optional_attrs ~w(input output)

  def changeset(%__MODULE__{} = internal_transaction, attrs \\ %{}) do
    internal_transaction
    |> cast(attrs, @required_attrs ++ @optional_attrs)
    |> validate_required(@required_attrs)
    |> foreign_key_constraint(:transaction_id)
    |> foreign_key_constraint(:to_address_id)
    |> foreign_key_constraint(:from_address_id)
    |> unique_constraint(:transaction_id, name: :internal_transactions_transaction_id_index_index)
  end

  def null, do: %__MODULE__{}
end
