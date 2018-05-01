defmodule Explorer.Chain.Receipt do
  @moduledoc "Captures a Web3 Transaction Receipt."

  use Explorer.Schema

  alias Explorer.Chain.{Gas, Hash, Log, Transaction}
  alias Explorer.Chain.Receipt.Status

  # Constants

  @optional_attrs ~w()a
  @required_attrs ~w(cumulative_gas_used gas_used status transaction_hash transaction_index)a
  @allowed_attrs @optional_attrs ++ @required_attrs

  # Types

  @typedoc """
  * `cumulative_gas_used` - the cumulative gas used in `transaction`'s `t:Explorer.Chain.Block.t/0` before
      `transaction`'s `index`
  * `gas_used` - the gas used for just `transaction`
  * `logs` - events that occurred while mining the `transaction`
  * `status` - whether the transaction was successfully mined or failed
  * `transaction` - the transaction for which this receipt is for
  * `transaction_hash` - foreign key for `transaction`
  * `transaction_index` - index of `transaction` in its `t:Explorer.Chain.Block.t/0`.
  """
  @type t :: %__MODULE__{
          cumulative_gas_used: Gas.t(),
          gas_used: Gas.t(),
          logs: %Ecto.Association.NotLoaded{} | [Log.t()],
          status: Status.t(),
          transaction: %Ecto.Association.NotLoaded{} | Transaction.t(),
          transaction_hash: Hash.Full.t(),
          transaction_index: non_neg_integer()
        }

  # Schema

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
