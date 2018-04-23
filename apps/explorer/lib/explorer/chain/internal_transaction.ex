defmodule Explorer.Chain.InternalTransaction do
  @moduledoc "Models internal transactions."

  use Explorer.Schema

  alias Explorer.Chain.{Address, Gas, Hash, Transaction, Wei}

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
  * `from_address_hash` - hash of the source of the `value`
  * `gas` - the amount of gas allowed
  * `gas_used` - the amount of gas used
  * `index` - the index of this internal transaction inside the `transaction`
  * `input` - input bytes to the call
  * `output` - output bytes from the call
  * `to_address` - the sink of the `value`
  * `to_address_hash` - hash of the sink of the `value`
  * `trace_address` - list of traces
  * `transaction` - transaction in which this transaction occured
  * `transaction_id` - foreign key for `transaction`
  * `value` - value of transfered from `from_address` to `to_address`
  """
  @type t :: %__MODULE__{
          call_type: call_type,
          from_address: %Ecto.Association.NotLoaded{} | Address.t(),
          from_address_hash: Hash.Truncated.t(),
          gas: Gas.t(),
          gas_used: Gas.t(),
          index: non_neg_integer(),
          input: String.t(),
          output: String.t(),
          to_address: %Ecto.Association.NotLoaded{} | Address.t(),
          to_address_hash: Hash.Truncated.t(),
          trace_address: [non_neg_integer()],
          transaction: %Ecto.Association.NotLoaded{} | Transaction.t(),
          transaction_hash: Explorer.Chain.Hash.t(),
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
    field(:value, :decimal)

    timestamps()

    belongs_to(
      :from_address,
      Address,
      foreign_key: :from_address_hash,
      references: :hash,
      type: Hash.Truncated
    )

    belongs_to(
      :to_address,
      Address,
      foreign_key: :to_address_hash,
      references: :hash,
      type: Hash.Truncated
    )

    belongs_to(:transaction, Transaction, foreign_key: :transaction_hash, references: :hash, type: Hash.Full)
  end

  @optional_attrs ~w(input output)
  @required_attrs ~w(call_type from_address_hash gas gas_used index to_address_hash trace_address transaction_hash
                     value)a
  @allowed_attrs @optional_attrs ++ @required_attrs

  def changeset(%__MODULE__{} = internal_transaction, attrs \\ %{}) do
    internal_transaction
    |> cast(attrs, @allowed_attrs)
    |> validate_required(@required_attrs)
    |> foreign_key_constraint(:from_address_hash)
    |> foreign_key_constraint(:to_address_hash)
    |> foreign_key_constraint(:transaction_hash)
    |> unique_constraint(:transaction_hash)
  end

  def extract(trace, transaction_hash, %{} = timestamps) do
    %{
      transaction_hash: transaction_hash,
      index: 0,
      call_type: trace["action"]["callType"] || trace["type"],
      to_address_hash: to_address(trace),
      from_address_hash: trace |> from_address(),
      trace_address: trace["traceAddress"],
      value: trace["action"]["value"],
      gas: trace["action"]["gas"],
      gas_used: gas_used(trace),
      input: trace["action"]["input"],
      output: trace["result"]["output"],
      # error: trace["error"],
      inserted_at: Map.fetch!(timestamps, :inserted_at),
      updated_at: Map.fetch!(timestamps, :updated_at)
    }
  end

  defp from_address(%{"action" => %{"from" => address}}), do: address

  defp gas_used(%{"result" => %{"gasUsed" => gas}}), do: gas
  defp gas_used(%{"error" => _error}), do: 0

  defp to_address(%{"action" => %{"to" => address}})
       when not is_nil(address),
       do: address

  defp to_address(%{"result" => %{"address" => address}}), do: address
  defp to_address(%{"error" => _error}), do: nil
end
