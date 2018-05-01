defmodule Explorer.Chain.InternalTransaction do
  @moduledoc "Models internal transactions."

  use Explorer.Schema

  alias Explorer.Chain.{Address, Gas, Hash, Transaction, Wei}
  alias Explorer.Chain.InternalTransaction.{CallType, Type}

  @typedoc """
  * `call_type` - the type of call.  `nil` when `type` is not `:call`.
  * `error` - error message when `:call` `type` errors
  * `from_address` - the source of the `value`
  * `from_address_hash` - hash of the source of the `value`
  * `gas` - the amount of gas allowed
  * `gas_used` - the amount of gas used.  `nil` when a call errors.
  * `index` - the index of this internal transaction inside the `transaction`
  * `input` - input bytes to the call
  * `output` - output bytes from the call.  `nil` when a call errors.
  * `to_address` - the sink of the `value`
  * `to_address_hash` - hash of the sink of the `value`
  * `trace_address` - list of traces
  * `transaction` - transaction in which this transaction occured
  * `transaction_id` - foreign key for `transaction`
  * `type` - type of internal transaction
  * `value` - value of transfered from `from_address` to `to_address`
  """
  @type t :: %__MODULE__{
          call_type: CallType.t() | nil,
          error: String.t(),
          from_address: %Ecto.Association.NotLoaded{} | Address.t(),
          from_address_hash: Hash.Truncated.t(),
          gas: Gas.t(),
          gas_used: Gas.t() | nil,
          index: non_neg_integer(),
          input: String.t(),
          output: String.t() | nil,
          to_address: %Ecto.Association.NotLoaded{} | Address.t(),
          to_address_hash: Hash.Truncated.t(),
          trace_address: [non_neg_integer()],
          transaction: %Ecto.Association.NotLoaded{} | Transaction.t(),
          transaction_hash: Explorer.Chain.Hash.t(),
          type: Type.t(),
          value: Wei.t()
        }

  schema "internal_transactions" do
    field(:call_type, CallType)
    field(:created_contract_code, :string)
    field(:error, :string)
    field(:gas, :decimal)
    field(:gas_used, :decimal)
    field(:index, :integer)
    field(:init, :string)
    field(:input, :string)
    field(:output, :string)
    field(:trace_address, {:array, :integer})
    field(:type, Type)
    field(:value, :decimal)

    timestamps()

    belongs_to(
      :created_contract_address,
      Address,
      foreign_key: :created_contract_address_hash,
      references: :hash,
      type: Hash.Truncated
    )

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

  def changeset(%__MODULE__{} = internal_transaction, attrs \\ %{}) do
    internal_transaction
    |> cast(attrs, ~w(type)a)
    |> type_changeset(attrs)
  end

  def changes_to_address_hash_set(changes) do
    Enum.reduce(~w(created_contract_address_hash from_address_hash to_address_hash)a, MapSet.new(), fn field, acc ->
      case Map.get(changes, field) do
        nil -> acc
        value -> MapSet.put(acc, value)
      end
    end)
  end

  ## Private Functions

  defp type_changeset(changeset, attrs) do
    type = get_field(changeset, :type)

    type_changeset(changeset, attrs, type)
  end

  @call_optional_fields ~w(error gas_used output)
  @call_required_fields ~w(call_type from_address_hash gas index to_address_hash trace_address transaction_hash value)a
  @call_allowed_fields @call_optional_fields ++ @call_required_fields

  defp type_changeset(changeset, attrs, :call) do
    changeset
    |> cast(attrs, @call_allowed_fields)
    |> validate_required(@call_required_fields)
    |> validate_call_error_or_result()
    |> foreign_key_constraint(:from_address_hash)
    |> foreign_key_constraint(:to_address_hash)
    |> foreign_key_constraint(:transaction_hash)
    |> unique_constraint(:index)
  end

  @create_optional_fields ~w(error created_contract_code created_contract_address_hash gas_used)
  @create_required_fields ~w(from_address_hash gas index init trace_address transaction_hash value)a
  @create_allowed_fields @create_optional_fields ++ @create_required_fields

  defp type_changeset(changeset, attrs, :create) do
    changeset
    |> cast(attrs, @create_allowed_fields)
    |> validate_required(@create_required_fields)
    |> validate_create_error_or_result()
    |> foreign_key_constraint(:created_contract_address_hash)
    |> foreign_key_constraint(:from_address_hash)
    |> foreign_key_constraint(:transaction_hash)
    |> unique_constraint(:index)
  end

  defp validate_disallowed(changeset, field, named_arguments) when is_atom(field) do
    case get_field(changeset, field) do
      nil -> changeset
      _ -> add_error(changeset, field, Keyword.get(named_arguments, :message, "can't be present"))
    end
  end

  defp validate_disallowed(changeset, fields, named_arguments) when is_list(fields) do
    Enum.reduce(fields, changeset, fn field, acc_changeset ->
      validate_disallowed(acc_changeset, field, named_arguments)
    end)
  end

  @call_success_fields ~w(gas_used output)a

  # Validates that :call `type` changeset either has an `error` or both `gas_used` and `output`
  defp validate_call_error_or_result(changeset) do
    case get_field(changeset, :error) do
      nil -> validate_required(changeset, @call_success_fields, message: "can't be blank for successful call")
      _ -> validate_disallowed(changeset, @call_success_fields, message: "can't be present for failed call")
    end
  end

  @create_success_fields ~w(created_contract_code created_contract_address_hash gas_used)a

  # Validates that :create `type` changeset either has an `:error` or both `:created_contract_code` and
  # `:created_contract_address_hash`
  defp validate_create_error_or_result(changeset) do
    case get_field(changeset, :error) do
      nil -> validate_required(changeset, @create_success_fields, message: "can't be blank for successful create")
      _ -> validate_disallowed(changeset, @create_success_fields, message: "can't be present for failed create")
    end
  end
end
