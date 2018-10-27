defmodule Explorer.Chain.InternalTransaction do
  @moduledoc "Models internal transactions."

  use Explorer.Schema

  alias Explorer.Chain.{Address, Data, Gas, Hash, Transaction, Wei}
  alias Explorer.Chain.InternalTransaction.{CallType, Type}

  @typedoc """
   * `block_number` - the `t:Explorer.Chain.Block.t/0` `number` that the `transaction` is collated into.
   * `call_type` - the type of call.  `nil` when `type` is not `:call`.
   * `created_contract_code` - the code of the contract that was created when `type` is `:create`.
   * `error` - error message when `:call` or `:create` `type` errors
   * `from_address` - the source of the `value`
   * `from_address_hash` - hash of the source of the `value`
   * `gas` - the amount of gas allowed
   * `gas_used` - the amount of gas used.  `nil` when a call errors.
   * `index` - the index of this internal transaction inside the `transaction`
   * `init` - the constructor arguments for creating `created_contract_code` when `type` is `:create`.
   * `input` - input bytes to the call
   * `output` - output bytes from the call.  `nil` when a call errors.
   * `to_address` - the sink of the `value`
   * `to_address_hash` - hash of the sink of the `value`
   * `trace_address` - list of traces
   * `transaction` - transaction in which this transaction occurred
   * `transaction_hash` - foreign key for `transaction`
   * `transaction_index` - the `t:Explorer.Chain.Transaction.t/0` `index` of `transaction` in `block_number`.
   * `type` - type of internal transaction
   * `value` - value of transferred from `from_address` to `to_address`
  """
  @type t :: %__MODULE__{
          block_number: Explorer.Chain.Block.block_number() | nil,
          call_type: CallType.t() | nil,
          created_contract_address: %Ecto.Association.NotLoaded{} | Address.t() | nil,
          created_contract_address_hash: Hash.t() | nil,
          created_contract_code: Data.t() | nil,
          error: String.t(),
          from_address: %Ecto.Association.NotLoaded{} | Address.t(),
          from_address_hash: Hash.Address.t(),
          gas: Gas.t(),
          gas_used: Gas.t() | nil,
          index: non_neg_integer(),
          init: Data.t() | nil,
          input: Data.t(),
          output: Data.t() | nil,
          to_address: %Ecto.Association.NotLoaded{} | Address.t() | nil,
          to_address_hash: Hash.Address.t() | nil,
          trace_address: [non_neg_integer()],
          transaction: %Ecto.Association.NotLoaded{} | Transaction.t(),
          transaction_hash: Hash.t(),
          transaction_index: Transaction.transaction_index() | nil,
          type: Type.t(),
          value: Wei.t()
        }

  @primary_key false
  schema "internal_transactions" do
    field(:call_type, CallType)
    field(:created_contract_code, Data)
    field(:error, :string)
    field(:gas, :decimal)
    field(:gas_used, :decimal)
    field(:index, :integer, primary_key: true)
    field(:init, Data)
    field(:input, Data)
    field(:output, Data)
    field(:trace_address, {:array, :integer})
    field(:type, Type)
    field(:value, Wei)
    field(:block_number, :integer)
    field(:transaction_index, :integer)

    timestamps()

    belongs_to(
      :created_contract_address,
      Address,
      foreign_key: :created_contract_address_hash,
      references: :hash,
      type: Hash.Address
    )

    belongs_to(
      :from_address,
      Address,
      foreign_key: :from_address_hash,
      references: :hash,
      type: Hash.Address
    )

    belongs_to(
      :to_address,
      Address,
      foreign_key: :to_address_hash,
      references: :hash,
      type: Hash.Address
    )

    belongs_to(:transaction, Transaction,
      foreign_key: :transaction_hash,
      primary_key: true,
      references: :hash,
      type: Hash.Full
    )
  end

  @doc """
  Validates that the `attrs` are valid.

  `:create` type traces generated when a contract is created are valid.  `created_contract_address_hash`,
  `from_address_hash`, and `transaction_hash` are converted to `t:Explorer.Chain.Hash.t/0`, and `type` is converted to
  `t:Explorer.Chain.InternalTransaction.Type.t/0`

      iex> changeset = Explorer.Chain.InternalTransaction.changeset(
      ...>   %Explorer.Chain.InternalTransaction{},
      ...>   %{
      ...>     created_contract_address_hash: "0xffc87239eb0267bc3ca2cd51d12fbf278e02ccb4",
      ...>     created_contract_code: "0x606060405260043610610062576000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff1680630900f01014610067578063445df0ac146100a05780638da5cb5b146100c9578063fdacd5761461011e575b600080fd5b341561007257600080fd5b61009e600480803573ffffffffffffffffffffffffffffffffffffffff16906020019091905050610141565b005b34156100ab57600080fd5b6100b3610224565b6040518082815260200191505060405180910390f35b34156100d457600080fd5b6100dc61022a565b604051808273ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff16815260200191505060405180910390f35b341561012957600080fd5b61013f600480803590602001909190505061024f565b005b60008060009054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff163373ffffffffffffffffffffffffffffffffffffffff161415610220578190508073ffffffffffffffffffffffffffffffffffffffff1663fdacd5766001546040518263ffffffff167c010000000000000000000000000000000000000000000000000000000002815260040180828152602001915050600060405180830381600087803b151561020b57600080fd5b6102c65a03f1151561021c57600080fd5b5050505b5050565b60015481565b6000809054906101000a900473ffffffffffffffffffffffffffffffffffffffff1681565b6000809054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff163373ffffffffffffffffffffffffffffffffffffffff1614156102ac57806001819055505b505600a165627a7a72305820a9c628775efbfbc17477a472413c01ee9b33881f550c59d21bee9928835c854b0029",
      ...>     from_address_hash: "0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca",
      ...>     gas: 4597044,
      ...>     gas_used: 166651,
      ...>     index: 0,
      ...>     init: "0x6060604052341561000f57600080fd5b336000806101000a81548173ffffffffffffffffffffffffffffffffffffffff021916908373ffffffffffffffffffffffffffffffffffffffff1602179055506102db8061005e6000396000f300606060405260043610610062576000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff1680630900f01014610067578063445df0ac146100a05780638da5cb5b146100c9578063fdacd5761461011e575b600080fd5b341561007257600080fd5b61009e600480803573ffffffffffffffffffffffffffffffffffffffff16906020019091905050610141565b005b34156100ab57600080fd5b6100b3610224565b6040518082815260200191505060405180910390f35b34156100d457600080fd5b6100dc61022a565b604051808273ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff16815260200191505060405180910390f35b341561012957600080fd5b61013f600480803590602001909190505061024f565b005b60008060009054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff163373ffffffffffffffffffffffffffffffffffffffff161415610220578190508073ffffffffffffffffffffffffffffffffffffffff1663fdacd5766001546040518263ffffffff167c010000000000000000000000000000000000000000000000000000000002815260040180828152602001915050600060405180830381600087803b151561020b57600080fd5b6102c65a03f1151561021c57600080fd5b5050505b5050565b60015481565b6000809054906101000a900473ffffffffffffffffffffffffffffffffffffffff1681565b6000809054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff163373ffffffffffffffffffffffffffffffffffffffff1614156102ac57806001819055505b505600a165627a7a72305820a9c628775efbfbc17477a472413c01ee9b33881f550c59d21bee9928835c854b0029",
      ...>     trace_address: [],
      ...>     transaction_hash: "0x3a3eb134e6792ce9403ea4188e5e79693de9e4c94e499db132be086400da79e6",
      ...>     type: "create",
      ...>     value: 0,
      ...>     block_number: 35
      ...>   }
      ...> )
      iex> changeset.valid?
      true
      iex> changeset.changes.created_contract_address_hash
      %Explorer.Chain.Hash{
        byte_count: 20,
        bytes: <<255, 200, 114, 57, 235, 2, 103, 188, 60, 162, 205, 81, 209, 47, 191, 39, 142, 2, 204, 180>>
      }
      iex> changeset.changes.from_address_hash
      %Explorer.Chain.Hash{
        byte_count: 20,
        bytes: <<232, 221, 197, 199, 162, 210, 240, 215, 169, 121, 132, 89, 192, 16, 79, 223, 94, 152, 122, 202>>
      }
      iex> changeset.changes.transaction_hash
      %Explorer.Chain.Hash{
        byte_count: 32,
        bytes: <<58, 62, 177, 52, 230, 121, 44, 233, 64, 62, 164, 24, 142, 94, 121, 105, 61, 233, 228, 201, 78, 73, 157,
                177, 50, 190, 8, 100, 0, 218, 121, 230>>
      }
      iex> changeset.changes.type
      :create

  `:create` type can fail due to a Bad Instruction in the `init`, but these need to be valid, so we can display the
  failures.  `to_address_hash` is converted to `t:Explorer.Chain.Hash.t/0`.

      iex> changeset = Explorer.Chain.InternalTransaction.changeset(
      ...>   %Explorer.Chain.InternalTransaction{},
      ...>   %{
      ...>     error: "Bad instruction",
      ...>     from_address_hash: "0x78a42d3705fb3c26a4b54737a784bf064f0815fb",
      ...>     gas: 3946728,
      ...>     index: 0,
      ...>     init: "0x4bb278f3",
      ...>     trace_address: [],
      ...>     transaction_hash: "0x3c624bb4852fb5e35a8f45644cec7a486211f6ba89034768a2b763194f22f97d",
      ...>     type: "create",
      ...>     value: 0,
      ...>     block_number: 35,
      ...>     transaction_index: 0
      ...>   }
      iex> )
      iex> changeset.valid?
      true
      iex> changeset.changes.from_address_hash
      %Explorer.Chain.Hash{
        byte_count: 20,
        bytes: <<120, 164, 45, 55, 5, 251, 60, 38, 164, 181, 71, 55, 167, 132, 191, 6, 79, 8, 21, 251>>
      }

  `:call` type traces are generated when a method in a contrat is call.

      iex> changeset = Explorer.Chain.InternalTransaction.changeset(
      ...>   %Explorer.Chain.InternalTransaction{},
      ...>   %{
      ...>     call_type: "call",
      ...>     from_address_hash: "0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca",
      ...>     gas: 4677320,
      ...>     gas_used: 27770,
      ...>     index: 0,
      ...>     output: "0x",
      ...>     to_address_hash: "0x8bf38d4764929064f2d4d3a56520a76ab3df415b",
      ...>     trace_address: [],
      ...>     transaction_hash: "0x3a3eb134e6792ce9403ea4188e5e79693de9e4c94e499db132be086400da79e6",
      ...>     type: "call",
      ...>     value: 0,
      ...>     block_number: 35,
      ...>     transaction_index: 0
      ...>   }
      ...> )
      iex> changeset.valid?
      true

  `:call` type traces can also fail, in which case it will be reverted.

      iex> changeset = Explorer.Chain.InternalTransaction.changeset(
      ...>   %Explorer.Chain.InternalTransaction{},
      ...>   %{
      ...>     call_type: "call",
      ...>     error: "Reverted",
      ...>     from_address_hash: "0xc9266e6fdf5182dc47d27e0dc32bdff9e4cd2e32",
      ...>     gas: 7578728,
      ...>     index: 0,
      ...>     to_address_hash: "0xfdca0da4158740a93693441b35809b5bb463e527",
      ...>     trace_address: [],
      ...>     transaction_hash: "0xcd7c15dbbc797722bef6e1d551edfd644fc7f4fb2ccd6a7947b2d1ade9ed140b",
      ...>     type: "call",
      ...>     value: 10000000000000000,
      ...>     block_number: 35,
      ...>     transaction_index: 0
      ...>   }
      ...> )
      iex> changeset.valid?
      true

  Failed `:call`s are not allowed to set `gas_used` or `output` because they are part of the successful `result` object
  in the Parity JSONRPC response.

      iex> changeset = Explorer.Chain.InternalTransaction.changeset(
      ...>   %Explorer.Chain.InternalTransaction{},
      ...>   %{
      ...>     call_type: "call",
      ...>     error: "Reverted",
      ...>     from_address_hash: "0xc9266e6fdf5182dc47d27e0dc32bdff9e4cd2e32",
      ...>     gas: 7578728,
      ...>     gas_used: 7578727,
      ...>     index: 0,
      ...>     output: "0x",
      ...>     to_address_hash: "0xfdca0da4158740a93693441b35809b5bb463e527",
      ...>     trace_address: [],
      ...>     transaction_hash: "0xcd7c15dbbc797722bef6e1d551edfd644fc7f4fb2ccd6a7947b2d1ade9ed140b",
      ...>     type: "call",
      ...>     value: 10000000000000000,
      ...>     block_number: 35,
      ...>     transaction_index: 0
      ...>   }
      ...> )
      iex> changeset.valid?
      false
      iex> changeset.errors
      [
        output: {"can't be present for failed call", []},
        gas_used: {"can't be present for failed call", []}
      ]

  Likewise, successful `:call`s require `gas_used` and `output` to be set.

      iex> changeset = Explorer.Chain.InternalTransaction.changeset(
      ...>   %Explorer.Chain.InternalTransaction{},
      ...>   %{
      ...>     call_type: "call",
      ...>     from_address_hash: "0xc9266e6fdf5182dc47d27e0dc32bdff9e4cd2e32",
      ...>     gas: 7578728,
      ...>     index: 0,
      ...>     to_address_hash: "0xfdca0da4158740a93693441b35809b5bb463e527",
      ...>     trace_address: [],
      ...>     transaction_hash: "0xcd7c15dbbc797722bef6e1d551edfd644fc7f4fb2ccd6a7947b2d1ade9ed140b",
      ...>     type: "call",
      ...>     value: 10000000000000000,
      ...>     block_number: 35,
      ...>     transaction_index: 0
      ...>   }
      ...> )
      iex> changeset.valid?
      false
      iex> changeset.errors
      [
        gas_used: {"can't be blank for successful call", [validation: :required]},
        output: {"can't be blank for successful call", [validation: :required]}
      ]

  For failed `:create`, `created_contract_code`, `created_contract_address_hash`, and `gas_used` are not allowed to be
  set because they come from `result` object, which shouldn't be returned from Parity.

      iex> changeset = Explorer.Chain.InternalTransaction.changeset(
      ...>   %Explorer.Chain.InternalTransaction{},
      ...>   %{
      ...>     created_contract_address_hash: "0xffc87239eb0267bc3ca2cd51d12fbf278e02ccb4",
      ...>     created_contract_code: "0x606060405260043610610062576000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff1680630900f01014610067578063445df0ac146100a05780638da5cb5b146100c9578063fdacd5761461011e575b600080fd5b341561007257600080fd5b61009e600480803573ffffffffffffffffffffffffffffffffffffffff16906020019091905050610141565b005b34156100ab57600080fd5b6100b3610224565b6040518082815260200191505060405180910390f35b34156100d457600080fd5b6100dc61022a565b604051808273ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff16815260200191505060405180910390f35b341561012957600080fd5b61013f600480803590602001909190505061024f565b005b60008060009054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff163373ffffffffffffffffffffffffffffffffffffffff161415610220578190508073ffffffffffffffffffffffffffffffffffffffff1663fdacd5766001546040518263ffffffff167c010000000000000000000000000000000000000000000000000000000002815260040180828152602001915050600060405180830381600087803b151561020b57600080fd5b6102c65a03f1151561021c57600080fd5b5050505b5050565b60015481565b6000809054906101000a900473ffffffffffffffffffffffffffffffffffffffff1681565b6000809054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff163373ffffffffffffffffffffffffffffffffffffffff1614156102ac57806001819055505b505600a165627a7a72305820a9c628775efbfbc17477a472413c01ee9b33881f550c59d21bee9928835c854b0029",
      ...>     error: "Bad instruction",
      ...>     from_address_hash: "0x78a42d3705fb3c26a4b54737a784bf064f0815fb",
      ...>     gas: 3946728,
      ...>     gas_used: 166651,
      ...>     index: 0,
      ...>     init: "0x4bb278f3",
      ...>     trace_address: [],
      ...>     transaction_hash: "0x3c624bb4852fb5e35a8f45644cec7a486211f6ba89034768a2b763194f22f97d",
      ...>     type: "create",
      ...>     value: 0,
      ...>     block_number: 35,
      ...>     transaction_index: 0
      ...>   }
      iex> )
      iex> changeset.valid?
      false
      iex> changeset.errors
      [
        gas_used: {"can't be present for failed create", []},
        created_contract_address_hash: {"can't be present for failed create", []},
        created_contract_code: {"can't be present for failed create", []}
      ]

  For successful `:create`,  `created_contract_code`, `created_contract_address_hash`, and `gas_used` are required.

      iex> changeset = Explorer.Chain.InternalTransaction.changeset(
      ...>   %Explorer.Chain.InternalTransaction{},
      ...>   %{
      ...>     from_address_hash: "0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca",
      ...>     gas: 4597044,
      ...>     index: 0,
      ...>     init: "0x6060604052341561000f57600080fd5b336000806101000a81548173ffffffffffffffffffffffffffffffffffffffff021916908373ffffffffffffffffffffffffffffffffffffffff1602179055506102db8061005e6000396000f300606060405260043610610062576000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff1680630900f01014610067578063445df0ac146100a05780638da5cb5b146100c9578063fdacd5761461011e575b600080fd5b341561007257600080fd5b61009e600480803573ffffffffffffffffffffffffffffffffffffffff16906020019091905050610141565b005b34156100ab57600080fd5b6100b3610224565b6040518082815260200191505060405180910390f35b34156100d457600080fd5b6100dc61022a565b604051808273ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff16815260200191505060405180910390f35b341561012957600080fd5b61013f600480803590602001909190505061024f565b005b60008060009054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff163373ffffffffffffffffffffffffffffffffffffffff161415610220578190508073ffffffffffffffffffffffffffffffffffffffff1663fdacd5766001546040518263ffffffff167c010000000000000000000000000000000000000000000000000000000002815260040180828152602001915050600060405180830381600087803b151561020b57600080fd5b6102c65a03f1151561021c57600080fd5b5050505b5050565b60015481565b6000809054906101000a900473ffffffffffffffffffffffffffffffffffffffff1681565b6000809054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff163373ffffffffffffffffffffffffffffffffffffffff1614156102ac57806001819055505b505600a165627a7a72305820a9c628775efbfbc17477a472413c01ee9b33881f550c59d21bee9928835c854b0029",
      ...>     trace_address: [],
      ...>     transaction_hash: "0x3a3eb134e6792ce9403ea4188e5e79693de9e4c94e499db132be086400da79e6",
      ...>     type: "create",
      ...>     value: 0,
      ...>     block_number: 35,
      ...>     transaction_index: 0
      ...>   }
      ...> )
      iex> changeset.valid?
      false
      iex> changeset.errors
      [
        created_contract_code: {"can't be blank for successful create", [validation: :required]},
        created_contract_address_hash: {"can't be blank for successful create", [validation: :required]},
        gas_used: {"can't be blank for successful create", [validation: :required]}
      ]

  For `:suicide`s, it looks like a simple value transfer between the addresses.

      iex> changeset = Explorer.Chain.InternalTransaction.changeset(
      ...>   %Explorer.Chain.InternalTransaction{},
      ...>   %{
      ...>     from_address_hash: "0xa7542d78b9a0be6147536887e0065f16182d294b",
      ...>     index: 1,
      ...>     to_address_hash: "0x59e2e9ecf133649b1a7efc731162ff09d29ca5a5",
      ...>     trace_address: [0],
      ...>     transaction_hash: "0xb012b8c53498c669d87d85ed90f57385848b86d3f44ed14b2784ec685d6fda98",
      ...>     type: "suicide",
      ...>     value: 0,
      ...>     block_number: 35,
      ...>     transaction_index: 0
      ...>   }
      ...> )
      iex> changeset.valid?
      true

  """
  def changeset(%__MODULE__{} = internal_transaction, attrs \\ %{}) do
    internal_transaction
    |> cast(attrs, ~w(type)a)
    |> validate_required(~w(type)a)
    |> type_changeset(attrs)
  end

  defp type_changeset(changeset, attrs) do
    type = get_field(changeset, :type)

    type_changeset(changeset, attrs, type)
  end

  @call_optional_fields ~w(error gas_used output block_number transaction_index)
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

  @create_optional_fields ~w(error created_contract_code created_contract_address_hash gas_used block_number transaction_index)
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

  @suicide_optional_fields ~w(block_number transaction_index)
  @suicide_required_fields ~w(from_address_hash index to_address_hash trace_address transaction_hash type value)a
  @suicide_allowed_fields @suicide_optional_fields ++ @suicide_required_fields

  defp type_changeset(changeset, attrs, :suicide) do
    changeset
    |> cast(attrs, @suicide_allowed_fields)
    |> validate_required(@suicide_required_fields)
    |> foreign_key_constraint(:from_address_hash)
    |> foreign_key_constraint(:to_address_hash)
    |> unique_constraint(:index)
  end

  defp type_changeset(changeset, _, nil), do: changeset

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

  @doc """
  Adds to the given transaction's query a `where` with one of the conditions that the matched
  function returns.

  `where_address_fields_match(query, address_hash, :to)`
  - returns a query considering that the given address_hash is equal to to_address_hash from
    transactions' table.

  `where_address_fields_match(query, address_hash, :from)`
  - returns a query considering that the given address_hash is equal to from_address_hash from
    transactions' table.

  `where_address_fields_match(query, address_hash, nil)`
  - returns a query considering that the given address_hash can be: to_address_hash,
    from_address_hash, created_contract_address_hash from internal_transactions' table.
  """
  def where_address_fields_match(query, address_hash, :to) do
    where(query, [t], t.to_address_hash == ^address_hash)
  end

  def where_address_fields_match(query, address_hash, :from) do
    where(query, [t], t.from_address_hash == ^address_hash)
  end

  def where_address_fields_match(query, address_hash, nil) do
    where(
      query,
      [it],
      it.to_address_hash == ^address_hash or it.from_address_hash == ^address_hash or
        it.created_contract_address_hash == ^address_hash
    )
  end

  def where_is_different_from_parent_transaction(query) do
    where(
      query,
      [it],
      (it.type == ^:call and it.index > 0) or it.type != ^:call
    )
  end

  def where_block_number_is_not_null(query) do
    where(query, [t], not is_nil(t.block_number))
  end
end
