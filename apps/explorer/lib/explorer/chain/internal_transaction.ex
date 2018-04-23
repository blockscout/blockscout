defmodule Explorer.Chain.InternalTransaction do
  @moduledoc "Models internal transactions."

  use Explorer.Schema

  alias Explorer.Chain.{Address, Gas, Transaction, Wei}

  @typedoc """
  * `"call"`
  * `"callcode"`
  * `"delegatecall"`
  * `"none"`
  * `"staticcall"
  """
  @type call_type :: String.t()

  @typedoc """
  * `call_type` - the type of call
  * `from_address` - the source of the `value`
  * `from_address_id` - foreign key for `from_address`
  * `gas` - the amount of gas allowed
  * `gas_used` - the amount of gas used
  * `index` - the index of this internal transaction inside the `transaction`
  * `input` - input bytes to the call
  * `output` - output bytes from the call
  * `to_address` - the sink of the `value`
  * `to_address_id` - foreign key for `to_address`
  * `trace_address` - list of traces
  * `transaction` - transaction in which this transaction occured
  * `transaction_id` - foreign key for `transaction`
  * `value` - value of transfered from `from_address` to `to_address`
  """
  @type t :: %__MODULE__{
          call_type: call_type,
          from_address: %Ecto.Association.NotLoaded{} | Address.t(),
          from_address_id: non_neg_integer(),
          gas: Gas.t(),
          gas_used: Gas.t(),
          index: non_neg_integer(),
          input: String.t(),
          output: String.t(),
          to_address: %Ecto.Association.NotLoaded{} | Address.t(),
          to_address_id: non_neg_integer(),
          trace_address: [non_neg_integer()],
          transaction: %Ecto.Association.NotLoaded{} | Transaction.t(),
          transaction_id: non_neg_integer(),
          value: Wei.t()
        }

  schema "internal_transactions" do
    field(:call_type, :string)
    field(:gas, :decimal)
    field(:gas_used, :decimal)
    field(:index, :integer)
    field(:input, :string)
    field(:output, :string)
    field(:trace_address, {:array, :integer})
    field(:value, Wei)

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
end
