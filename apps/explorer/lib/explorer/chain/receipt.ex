defmodule Explorer.Chain.Receipt do
  @moduledoc "Captures a Web3 Transaction Receipt."

  use Explorer.Schema

  alias Explorer.Chain.{Hash, Log, Transaction}
  alias Explorer.Chain.Receipt.Status

  @optional_attrs ~w()a
  @required_attrs ~w(cumulative_gas_used gas_used status transaction_hash transaction_index)a
  @allowed_attrs @optional_attrs ++ @required_attrs

  @primary_key false
  schema "receipts" do
    field(:cumulative_gas_used, :decimal)
    field(:gas_used, :decimal)
    field(:status, Status)
    field(:transaction_index, :integer)

    belongs_to(:transaction, Transaction, foreign_key: :transaction_hash, references: :hash, type: Hash.Full)
    has_many(:logs, Log, foreign_key: :transaction_hash, references: :transaction_hash)

    timestamps()
  end

  # Functions

  def changeset(%__MODULE__{} = transaction_receipt, attrs \\ %{}) do
    transaction_receipt
    |> cast(attrs, @allowed_attrs)
    |> validate_required(@required_attrs)
    |> foreign_key_constraint(:transaction_hash)
    |> unique_constraint(:transaction_hash)
  end

  def changes_to_address_hash_set(_), do: MapSet.new()
end
