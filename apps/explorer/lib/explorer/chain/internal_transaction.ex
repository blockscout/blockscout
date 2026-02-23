defmodule Explorer.Chain.InternalTransaction do
  @moduledoc "Models internal transactions."

  use Explorer.Schema

  alias Explorer.{Chain, PagingOptions}

  alias Explorer.Chain.{
    Address,
    Block,
    Data,
    Hash,
    PendingOperationsHelper,
    Transaction,
    TransactionError,
    Wei
  }

  alias Explorer.Chain.Block.Reader.General, as: BlockReaderGeneral
  alias Explorer.Chain.Cache.BackgroundMigrations
  alias Explorer.Chain.DenormalizationHelper
  alias Explorer.Chain.InternalTransaction.{CallType, Type}
  alias Explorer.Migrator.DeleteZeroValueInternalTransactions
  alias Explorer.Utility.InternalTransactionHelper

  import Explorer.Chain.SmartContract.Proxy.Models.Implementation, only: [proxy_implementations_association: 0]

  @typep paging_options :: {:paging_options, PagingOptions.t()}
  @typep api? :: {:api?, true | false}

  @default_paging_options %PagingOptions{page_size: 50}

  @typedoc """
   * `block_number` - the `t:Explorer.Chain.Block.t/0` `number` that the `transaction` is collated into.
   * `call_type` - the type of call.  `nil` when `type` is not `:call`.
   * `created_contract_code` - the code of the contract that was created when `type` is `:create`.
   * `error` - error message when `:call` or `:create` `type` errors
   * `error_id` - foreign key for `t:Explorer.Chain.TransactionError.t/0`
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
   * `transaction` - transaction in which this internal transaction occurred
   * `transaction_hash` - foreign key for `transaction`
   * `transaction_index` - the `t:Explorer.Chain.Transaction.t/0` `index` of `transaction` in `block_number`.
   * `type` - type of internal transaction
   * `value` - value of transferred from `from_address` to `to_address`
   * `block` - block in which this internal transaction occurred
   * `block_hash` - foreign key for `block`
   * `block_index` - the index of this internal transaction inside the `block`
  """
  @primary_key false
  typed_schema "internal_transactions" do
    # todo: consider using enum: `field(:call_type, Ecto.Enum, values: [:call, :callcode, :delegatecall, :staticcall])`
    field(:call_type, CallType)
    field(:call_type_enum, Ecto.Enum, values: [:call, :callcode, :delegatecall, :staticcall, :invalid])
    field(:created_contract_code, Data)
    field(:error, :string)
    field(:error_id, :integer)
    field(:gas, :decimal)
    field(:gas_used, :decimal)
    field(:index, :integer, primary_key: true, null: false)
    field(:init, Data)
    field(:input, Data)
    field(:output, Data)
    field(:trace_address, {:array, :integer})
    # todo: consider using enum
    field(:type, Type, null: false)
    field(:value, Wei)
    # TODO: remove field after update PK migration is completed
    field(:block_hash, Hash.Full)
    field(:transaction_index, :integer, primary_key: true, null: false)
    # TODO: remove field after update PK migration is completed
    field(:block_index, :integer)

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
      type: Hash.Address,
      null: false
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
      references: :hash,
      type: Hash.Full,
      null: false
    )

    belongs_to(:block, Block,
      foreign_key: :block_number,
      references: :number,
      primary_key: true,
      type: :integer,
      where: [consensus: true]
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
      ...>     transaction_index: 0,
      ...>     type: "create",
      ...>     value: 0,
      ...>     block_number: 35,
      ...>     block_hash: "0xf6b4b8c88df3ebd252ec476328334dc026cf66606a84fb769b3d3cbccc8471bd"
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
      ...>     block_hash: "0xf6b4b8c88df3ebd252ec476328334dc026cf66606a84fb769b3d3cbccc8471bd",
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

  `:call` type traces are generated when a method in a contract is call.

      iex> changeset = Explorer.Chain.InternalTransaction.changeset(
      ...>   %Explorer.Chain.InternalTransaction{},
      ...>   %{
      ...>     block_number: 35,
      ...>     block_hash: "0xf6b4b8c88df3ebd252ec476328334dc026cf66606a84fb769b3d3cbccc8471bd",
      ...>     transaction_index: 0,
      ...>     transaction_hash: "0x3a3eb134e6792ce9403ea4188e5e79693de9e4c94e499db132be086400da79e6",
      ...>     index: 0,
      ...>     trace_address: [],
      ...>     call_type: "call",
      ...>     type: "call",
      ...>     from_address_hash: "0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca",
      ...>     to_address_hash: "0x8bf38d4764929064f2d4d3a56520a76ab3df415b",
      ...>     gas: 4677320,
      ...>     gas_used: 27770,
      ...>     input: "0x",
      ...>     output: "0x",
      ...>     value: 0,
      ...>   }
      ...> )
      iex> changeset.valid?
      true

  `:call` type traces can also fail, in which case it will be reverted.

      iex> changeset = Explorer.Chain.InternalTransaction.changeset(
      ...>   %Explorer.Chain.InternalTransaction{},
      ...>   %{
      ...>     block_number: 35,
      ...>     block_hash: "0xf6b4b8c88df3ebd252ec476328334dc026cf66606a84fb769b3d3cbccc8471bd",
      ...>     transaction_index: 0,
      ...>     transaction_hash: "0xcd7c15dbbc797722bef6e1d551edfd644fc7f4fb2ccd6a7947b2d1ade9ed140b",
      ...>     index: 0,
      ...>     trace_address: [],
      ...>     type: "call",
      ...>     call_type: "call",
      ...>     from_address_hash: "0xc9266e6fdf5182dc47d27e0dc32bdff9e4cd2e32",
      ...>     to_address_hash: "0xfdca0da4158740a93693441b35809b5bb463e527",
      ...>     gas: 7578728,
      ...>     input: "0x",
      ...>     error: "Reverted",
      ...>     value: 10000000000000000
      ...>   }
      ...> )
      iex> changeset.valid?
      true

  Failed `:call`s are not allowed to set `gas_used` or `output` because they are part of the successful `result` object
  in the Nethermind JSONRPC response.  They still need `input`, however.
  The changeset will be fixed by `validate_call_error_or_result`, therefore the changeset is still valid.

      iex> changeset = Explorer.Chain.InternalTransaction.changeset(
      ...>   %Explorer.Chain.InternalTransaction{},
      ...>   %{
      ...>     block_number: 35,
      ...>     block_hash: "0xf6b4b8c88df3ebd252ec476328334dc026cf66606a84fb769b3d3cbccc8471bd",
      ...>     transaction_index: 0,
      ...>     transaction_hash: "0xcd7c15dbbc797722bef6e1d551edfd644fc7f4fb2ccd6a7947b2d1ade9ed140b",
      ...>     index: 0,
      ...>     trace_address: [],
      ...>     type: "call",
      ...>     call_type: "call",
      ...>     from_address_hash: "0xc9266e6fdf5182dc47d27e0dc32bdff9e4cd2e32",
      ...>     to_address_hash: "0xfdca0da4158740a93693441b35809b5bb463e527",
      ...>     gas: 7578728,
      ...>     gas_used: 7578727,
      ...>     input: "0x",
      ...>     output: "0x",
      ...>     error: "Reverted",
      ...>     value: 10000000000000000
      ...>   }
      ...> )
      iex> changeset.valid?
      true

  Likewise, successful `:call`s require `input`, `gas_used` and `output` to be set.

      iex> changeset = Explorer.Chain.InternalTransaction.changeset(
      ...>   %Explorer.Chain.InternalTransaction{},
      ...>   %{
      ...>     block_number: 35,
      ...>     block_hash: "0xf6b4b8c88df3ebd252ec476328334dc026cf66606a84fb769b3d3cbccc8471bd",
      ...>     transaction_index: 0,
      ...>     transaction_hash: "0xcd7c15dbbc797722bef6e1d551edfd644fc7f4fb2ccd6a7947b2d1ade9ed140b",
      ...>     index: 0,
      ...>     trace_address: [],
      ...>     type: "call",
      ...>     call_type: "call",
      ...>     from_address_hash: "0xc9266e6fdf5182dc47d27e0dc32bdff9e4cd2e32",
      ...>     to_address_hash: "0xfdca0da4158740a93693441b35809b5bb463e527",
      ...>     input: "0x",
      ...>     gas: 7578728,
      ...>     value: 10000000000000000
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
  set because they come from `result` object, which shouldn't be returned from Nethermind.
  The changeset will be fixed by `validate_create_error_or_result`, therefore the changeset is still valid.

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
      ...>     block_hash: "0xf6b4b8c88df3ebd252ec476328334dc026cf66606a84fb769b3d3cbccc8471bd",
      ...>     transaction_index: 0
      ...>   }
      iex> )
      iex> changeset.valid?
      true

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
      ...>     block_hash: "0xf6b4b8c88df3ebd252ec476328334dc026cf66606a84fb769b3d3cbccc8471bd",
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

  For `:selfdestruct`s, it looks like a simple value transfer between the addresses.

      iex> changeset = Explorer.Chain.InternalTransaction.changeset(
      ...>   %Explorer.Chain.InternalTransaction{},
      ...>   %{
      ...>     from_address_hash: "0xa7542d78b9a0be6147536887e0065f16182d294b",
      ...>     index: 1,
      ...>     to_address_hash: "0x59e2e9ecf133649b1a7efc731162ff09d29ca5a5",
      ...>     trace_address: [0],
      ...>     transaction_hash: "0xb012b8c53498c669d87d85ed90f57385848b86d3f44ed14b2784ec685d6fda98",
      ...>     type: "selfdestruct",
      ...>     value: 0,
      ...>     block_number: 35,
      ...>     block_hash: "0xf6b4b8c88df3ebd252ec476328334dc026cf66606a84fb769b3d3cbccc8471bd",
      ...>     transaction_index: 0
      ...>   }
      ...> )
      iex> changeset.valid?
      true

  """
  def changeset(%__MODULE__{} = internal_transaction, attrs \\ %{}) do
    base_attributes = ~w(transaction_index index type)a

    all_attributes =
      if InternalTransactionHelper.primary_key_updated?() do
        [:block_number | base_attributes]
      else
        [:block_hash, :block_index | base_attributes]
      end

    internal_transaction
    |> cast(attrs, all_attributes)
    |> validate_required(all_attributes)
    |> type_changeset(attrs)
  end

  @doc """
  Accepts changes without `:type` but with `:block_number`, if `:type` is defined
  works like `changeset`, except allowing `:block_hash` to be undefined.

  This is used because the `internal_transactions` runner can derive such values
  on its own or use empty types to know that a block has no internal transactions.
  """
  def blockless_changeset(%__MODULE__{} = internal_transaction, attrs \\ %{}) do
    changeset = cast(internal_transaction, attrs, ~w(type block_number transaction_index index)a)

    if validate_required(changeset, ~w(type)a).valid? do
      type_changeset(changeset, attrs)
    else
      validate_required(changeset, ~w(block_number)a)
    end
  end

  defp type_changeset(changeset, attrs) do
    type = get_field(changeset, :type)

    type_changeset(changeset, attrs, type)
  end

  @call_optional_fields ~w(error error_id gas_used output block_number value)a
  @call_required_fields ~w(call_type_enum from_address_hash gas input to_address_hash transaction_hash)a
  @call_allowed_fields @call_optional_fields ++ @call_required_fields

  defp type_changeset(changeset, attrs, :call) do
    changeset
    |> cast(adjust_call_type(attrs), @call_allowed_fields)
    |> validate_required(@call_required_fields)
    # TODO consider removing
    |> validate_call_error_or_result()
    |> check_constraint(:call_type_enum,
      message: ~S|can't be blank when type is 'call'|,
      name: :call_has_call_type_enum
    )
    |> check_constraint(:input, message: ~S|can't be blank when type is 'call'|, name: :call_has_input)
    |> foreign_key_constraint(:transaction_hash)
  end

  @create_optional_fields ~w(error error_id created_contract_code created_contract_address_hash gas_used block_number value)a
  @create_required_fields ~w(from_address_hash gas init transaction_hash)a
  @create_allowed_fields @create_optional_fields ++ @create_required_fields

  defp type_changeset(changeset, attrs, type) when type in [:create, :create2] do
    changeset
    |> cast(attrs, @create_allowed_fields)
    |> validate_required(@create_required_fields)
    # TODO consider removing
    |> validate_create_error_or_result()
    |> check_constraint(:init, message: ~S|can't be blank when type is 'create'|, name: :create_has_init)
    |> foreign_key_constraint(:transaction_hash)
  end

  @selfdestruct_optional_fields ~w(block_number value)a
  @selfdestruct_required_fields ~w(from_address_hash to_address_hash transaction_hash type)a
  @selfdestruct_allowed_fields @selfdestruct_optional_fields ++ @selfdestruct_required_fields

  defp type_changeset(changeset, attrs, :selfdestruct) do
    changeset
    |> cast(attrs, @selfdestruct_allowed_fields)
    |> validate_required(@selfdestruct_required_fields)
  end

  @stop_optional_fields ~w(from_address_hash gas gas_used error error_id value)a
  @stop_required_fields ~w(block_number transaction_hash type)a
  @stop_allowed_fields @stop_optional_fields ++ @stop_required_fields

  defp type_changeset(changeset, attrs, :stop) do
    changeset
    |> cast(attrs, @stop_allowed_fields)
    |> validate_required(@stop_required_fields)
  end

  defp type_changeset(changeset, _, nil), do: changeset

  defp adjust_call_type(%{call_type_enum: _} = attrs), do: attrs

  defp adjust_call_type(%{call_type: call_type} = attrs) when not is_nil(call_type) do
    attrs
    |> Map.delete(:call_type)
    |> Map.put(:call_type_enum, call_type)
  end

  defp adjust_call_type(attrs), do: attrs

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

  # Validates that :call `type` changeset either has an `error` or both `gas_used` and `output`
  defp validate_call_error_or_result(changeset) do
    case {get_field(changeset, :error), get_field(changeset, :error_id)} do
      {nil, nil} ->
        validate_required(changeset, [:gas_used, :output], message: "can't be blank for successful call")

      _ ->
        changeset
        |> delete_change(:gas_used)
        |> delete_change(:output)
        |> validate_disallowed([:output], message: "can't be present for failed call")
    end
  end

  @create_success_fields ~w(created_contract_code created_contract_address_hash gas_used)a

  # Validates that :create `type` changeset either has an `:error` or both `:created_contract_code` and
  # `:created_contract_address_hash`
  defp validate_create_error_or_result(changeset) do
    case {get_field(changeset, :error), get_field(changeset, :error_id)} do
      {nil, nil} ->
        validate_required(changeset, @create_success_fields, message: "can't be blank for successful create")

      _ ->
        changeset
        |> delete_change(:created_contract_code)
        |> delete_change(:created_contract_address_hash)
        |> delete_change(:gas_used)
        |> validate_disallowed(@create_success_fields, message: "can't be present for failed create")
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
    if BackgroundMigrations.get_empty_internal_transactions_data_finished() do
      where(query, [t], t.to_address_hash == ^address_hash)
    else
      where(
        query,
        [t],
        t.to_address_hash == ^address_hash or
          (is_nil(t.to_address_hash) and t.created_contract_address_hash == ^address_hash)
      )
    end
  end

  def where_address_fields_match(query, address_hash, :from) do
    where(query, [t], t.from_address_hash == ^address_hash)
  end

  def where_address_fields_match(query, address_hash, :to_address_hash) do
    if BackgroundMigrations.get_empty_internal_transactions_data_finished() do
      where(query, [it], it.to_address_hash == ^address_hash and is_nil(it.created_contract_address_hash))
    else
      where(query, [it], it.to_address_hash == ^address_hash)
    end
  end

  def where_address_fields_match(query, address_hash, :from_address_hash) do
    where(query, [it], it.from_address_hash == ^address_hash)
  end

  def where_address_fields_match(query, address_hash, :created_contract_address_hash) do
    where(query, [it], it.created_contract_address_hash == ^address_hash)
  end

  def where_address_fields_match(query, address_hash, _) do
    base_address_where(query, address_hash)
  end

  defp base_address_where(query, address_hash) do
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

  @doc """
  Filters out internal_transactions of blocks or transactions that are flagged as needing fetching
  of internal_transactions
  """
  @spec where_nonpending_operation(Ecto.Query.t() | module()) :: Ecto.Query.t()
  def where_nonpending_operation(query \\ __MODULE__) do
    case PendingOperationsHelper.pending_operations_type() do
      "blocks" ->
        where(
          query,
          [it],
          fragment("(SELECT 1 FROM pending_block_operations WHERE block_number = ? LIMIT 1) IS NULL", it.block_number)
        )

      "transactions" ->
        where(
          query,
          [it],
          fragment(
            "(SELECT 1 FROM pending_transaction_operations WHERE transaction_hash = ? LIMIT 1) IS NULL",
            it.transaction_hash
          )
        )
    end
  end

  @doc """
  `t:Explorer.Chain.InternalTransaction/0`s in `t:Explorer.Chain.Transaction.t/0` with `hash`.

  ## Options

    * `:necessity_by_association` - use to load `t:association/0` as `:required` or `:optional`.  If an association is
      `:required`, and the `t:Explorer.Chain.InternalTransaction.t/0` has no associated record for that association,
      then the `t:Explorer.Chain.InternalTransaction.t/0` will not be included in the list.
    * `:paging_options` - a `t:Explorer.PagingOptions.t/0` used to specify the `:page_size` and
      `:key` (a tuple of the lowest/oldest `{index}`). Results will be the internal transactions older than
      the `index` that is passed.

  """
  @spec all_transaction_to_internal_transactions(Hash.Full.t(), [
          Chain.paging_options() | Chain.necessity_by_association_option() | Chain.api?()
        ]) :: [
          __MODULE__.t()
        ]
  def all_transaction_to_internal_transactions(hash, options \\ []) when is_list(options) do
    necessity_by_association = Keyword.get(options, :necessity_by_association, %{})
    paging_options = Keyword.get(options, :paging_options, @default_paging_options)

    __MODULE__
    |> for_parent_transaction(hash)
    |> Chain.join_associations(necessity_by_association)
    |> where_nonpending_operation()
    |> page_internal_transaction(paging_options)
    |> limit(^paging_options.page_size)
    |> order_by([internal_transaction], asc: internal_transaction.index)
    |> Chain.select_repo(options).all()
    |> preload_error(options)
  end

  @spec transaction_to_internal_transactions(Hash.Full.t(), [
          Chain.paging_options() | Chain.necessity_by_association_option() | Chain.api?()
        ]) ::
          [
            __MODULE__.t()
          ]
  def transaction_to_internal_transactions(hash, options \\ []) when is_list(options) do
    necessity_by_association = Keyword.get(options, :necessity_by_association, %{})
    paging_options = Keyword.get(options, :paging_options, @default_paging_options)

    __MODULE__
    |> for_parent_transaction(hash)
    |> Chain.join_associations(necessity_by_association)
    |> where_is_different_from_parent_transaction()
    |> where_nonpending_operation()
    |> page_internal_transaction(paging_options)
    |> limit(^paging_options.page_size)
    |> order_by([internal_transaction], asc: internal_transaction.index)
    |> preload(:block)
    |> Chain.select_repo(options).all()
    |> preload_error(options)
  end

  @spec block_to_internal_transactions(non_neg_integer(), [
          Chain.paging_options() | Chain.necessity_by_association_option() | Chain.api?()
        ]) ::
          [
            __MODULE__.t()
          ]
  def block_to_internal_transactions(block_number, options \\ []) when is_list(options) do
    necessity_by_association = Keyword.get(options, :necessity_by_association, %{})
    paging_options = Keyword.get(options, :paging_options, @default_paging_options)
    type_filter = Keyword.get(options, :type, [])
    call_type_filter = Keyword.get(options, :call_type, [])

    __MODULE__
    |> where([internal_transaction], internal_transaction.block_number == ^block_number)
    |> Chain.join_associations(necessity_by_association)
    |> where_is_different_from_parent_transaction()
    |> where_nonpending_operation()
    |> page_block_internal_transaction(paging_options)
    |> filter_by_type(type_filter, call_type_filter)
    |> filter_by_call_type(call_type_filter)
    |> limit(^paging_options.page_size)
    |> order_by([internal_transaction], asc: internal_transaction.transaction_index, asc: internal_transaction.index)
    |> Chain.select_repo(options).all()
    |> preload_error(options)
  end

  @doc """
  `t:Explorer.Chain.InternalTransaction/0`s from the address with the given `hash`.

  This function excludes any internal transactions in the results where the
  internal transaction has no siblings within the parent transaction.

  ## Options

    * `:direction` - if specified, will filter internal transactions by address type. If `:to` is specified, only
      internal transactions where the "to" address matches will be returned. Likewise, if `:from` is specified, only
      internal transactions where the "from" address matches will be returned. If `:direction` is omitted, internal
      transactions either to or from the address will be returned.
    * `:necessity_by_association` - use to load `t:association/0` as `:required` or `:optional`. If an association is
      `:required`, and the `t:Explorer.Chain.InternalTransaction.t/0` has no associated record for that association,
      then the `t:Explorer.Chain.InternalTransaction.t/0` will not be included in the page `entries`.
    * `:paging_options` - a `t:Explorer.PagingOptions.t/0` used to specify the `:page_size` and
      `:key` (a tuple of the lowest/oldest `{block_number, transaction_index, index}`) and. Results will be the internal
      transactions older than the `block_number`, `transaction index`, and `index` that are passed.

  """
  @spec address_to_internal_transactions(Hash.Address.t(), [paging_options | Chain.necessity_by_association_option()]) ::
          [
            __MODULE__.t()
          ]
  def address_to_internal_transactions(hash, options \\ []) do
    case Keyword.get(options, :paging_options, @default_paging_options) do
      %PagingOptions{key: {0, 0, 0}} -> []
      _ -> fetch_from_db_by_address(hash, options)
    end
  end

  @doc """
  Deduplicates and trims internal transactions based on the page_size specified in paging options.
  """
  @spec deduplicate_and_trim_internal_transactions([__MODULE__.t()], PagingOptions.t()) :: [__MODULE__.t()]
  def deduplicate_and_trim_internal_transactions(internal_transactions, paging_options) do
    internal_transactions
    |> Enum.uniq_by(fn internal_transaction ->
      {internal_transaction.transaction_hash, internal_transaction.index}
    end)
    |> Enum.take(paging_options.page_size)
  end

  @doc """
    Determines whether internal transactions for the given block number are present in the database.

    When the DeleteZeroValueInternalTransactions migration is enabled, internal
    transactions for blocks older than the border_number may have been removed
    from the database. This function returns false for those old blocks,
    indicating that the data must be fetched on-demand from RPC instead.

    ## Parameters
    - `block_number`: The block number to check, or nil for pending transactions

    ## Returns
    - `true` if internal transactions are present in the database
    - `false` if internal transactions have been deleted and must be fetched on-demand
  """
  @spec present_in_db?(non_neg_integer() | nil) :: boolean()
  def present_in_db?(nil), do: true

  def present_in_db?(block_number) do
    if Application.get_env(:explorer, DeleteZeroValueInternalTransactions)[:enabled] do
      border_number = DeleteZeroValueInternalTransactions.border_number()
      is_nil(border_number) or border_number < block_number
    else
      true
    end
  end

  @doc """
    Fetches internal transactions from the database for the given address hash with specified options.

    When direction is nil or empty, the function performs a union query across
    all three address roles (to_address, from_address, created_contract_address)
    and deduplicates the results. When direction is specified, it performs a
    single query filtering by the specified address field.

    ## Parameters
    - `hash`: The address hash to query internal transactions for
    - `options`: Keyword list with the following keys:
      - `:necessity_by_association` - associations to preload as required or optional
      - `:direction` - filter by address role (:to, :from, :to_address_hash, :from_address_hash, :created_contract_address_hash, or nil for all)
      - `:from_block` - starting block number for the query range
      - `:to_block` - ending block number for the query range
      - `:paging_options` - pagination options including page_size and key

    ## Returns
    - List of InternalTransaction structs matching the query, with deduplication applied when direction is nil
  """
  @spec fetch_from_db_by_address(Hash.Address.t(), Keyword.t()) :: [__MODULE__.t()]
  def fetch_from_db_by_address(hash, options) do
    necessity_by_association = Keyword.get(options, :necessity_by_association, %{})
    direction = Keyword.get(options, :direction)

    from_block = Chain.from_block(options)
    to_block = Chain.to_block(options)

    paging_options = Keyword.get(options, :paging_options, @default_paging_options)

    if direction == nil || direction == "" do
      query_to_address_hash_wrapped =
        __MODULE__
        |> where_nonpending_operation()
        |> where_address_fields_match(hash, :to)
        |> BlockReaderGeneral.where_block_number_in_period(from_block, to_block)
        |> where_is_different_from_parent_transaction()
        |> common_where_limit_order(paging_options)
        |> Chain.wrapped_union_subquery()

      query_from_address_hash_wrapped =
        __MODULE__
        |> where_nonpending_operation()
        |> where_address_fields_match(hash, :from_address_hash)
        |> BlockReaderGeneral.where_block_number_in_period(from_block, to_block)
        |> where_is_different_from_parent_transaction()
        |> common_where_limit_order(paging_options)
        |> Chain.wrapped_union_subquery()

      query_to_address_hash_wrapped
      |> union_all(^query_from_address_hash_wrapped)
      |> Chain.wrapped_union_subquery()
      |> common_where_and_order(paging_options)
      |> preload(:block)
      |> Chain.join_associations(necessity_by_association)
      |> Chain.select_repo(options).all()
      |> deduplicate_and_trim_internal_transactions(paging_options)
      |> preload_error(options)
    else
      __MODULE__
      |> where_nonpending_operation()
      |> where_address_fields_match(hash, direction)
      |> BlockReaderGeneral.where_block_number_in_period(from_block, to_block)
      |> where_is_different_from_parent_transaction()
      |> common_where_limit_order(paging_options)
      |> preload(:block)
      |> Chain.join_associations(necessity_by_association)
      |> Chain.select_repo(options).all()
      |> preload_error(options)
    end
  end

  defp common_where_limit_order(query, paging_options) do
    query
    |> common_where_and_order(paging_options)
    |> limit(^paging_options.page_size)
  end

  defp common_where_and_order(query, paging_options) do
    query
    |> page_internal_transaction(paging_options, %{index_internal_transaction_desc_order: true})
    |> order_by(
      [it],
      desc: it.block_number,
      desc: it.transaction_index,
      desc: it.index
    )
  end

  defp page_internal_transaction(_, _, _ \\ %{index_internal_transaction_desc_order: false})

  defp page_internal_transaction(query, %PagingOptions{key: nil}, _), do: query

  defp page_internal_transaction(query, %PagingOptions{key: {block_number, transaction_index, index}}, %{
         index_internal_transaction_desc_order: desc_order
       }) do
    hardcoded_where_for_page_internal_transaction(query, block_number, transaction_index, index, desc_order)
  end

  defp page_internal_transaction(query, %PagingOptions{key: {0}}, %{index_internal_transaction_desc_order: desc_order}) do
    if desc_order do
      query
    else
      where(query, [internal_transaction], internal_transaction.index > 0)
    end
  end

  defp page_internal_transaction(query, %PagingOptions{key: {index}}, %{
         index_internal_transaction_desc_order: desc_order
       }) do
    if desc_order do
      where(query, [internal_transaction], internal_transaction.index < ^index)
    else
      where(query, [internal_transaction], internal_transaction.index > ^index)
    end
  end

  defp hardcoded_where_for_page_internal_transaction(query, 0, 0, index, false),
    do:
      where(
        query,
        [internal_transaction],
        internal_transaction.block_number == 0 and
          internal_transaction.transaction_index == 0 and internal_transaction.index > ^index
      )

  defp hardcoded_where_for_page_internal_transaction(query, block_number, 0, index, false),
    do:
      where(
        query,
        [internal_transaction],
        internal_transaction.block_number < ^block_number or
          (internal_transaction.block_number == ^block_number and
             internal_transaction.transaction_index == 0 and internal_transaction.index > ^index)
      )

  defp hardcoded_where_for_page_internal_transaction(query, block_number, transaction_index, index, false),
    do:
      where(
        query,
        [internal_transaction],
        internal_transaction.block_number < ^block_number or
          (internal_transaction.block_number == ^block_number and
             internal_transaction.transaction_index < ^transaction_index) or
          (internal_transaction.block_number == ^block_number and
             internal_transaction.transaction_index == ^transaction_index and internal_transaction.index > ^index)
      )

  defp hardcoded_where_for_page_internal_transaction(query, 0, 0, index, true),
    do:
      where(
        query,
        [internal_transaction],
        internal_transaction.block_number == 0 and
          internal_transaction.transaction_index == 0 and internal_transaction.index < ^index
      )

  defp hardcoded_where_for_page_internal_transaction(query, block_number, 0, 0, true),
    do:
      where(
        query,
        [internal_transaction],
        internal_transaction.block_number < ^block_number
      )

  defp hardcoded_where_for_page_internal_transaction(query, block_number, 0, index, true),
    do:
      where(
        query,
        [internal_transaction],
        internal_transaction.block_number < ^block_number or
          (internal_transaction.block_number == ^block_number and
             internal_transaction.transaction_index == 0 and internal_transaction.index < ^index)
      )

  defp hardcoded_where_for_page_internal_transaction(query, block_number, transaction_index, 0, true),
    do:
      where(
        query,
        [internal_transaction],
        internal_transaction.block_number < ^block_number or
          (internal_transaction.block_number == ^block_number and
             internal_transaction.transaction_index < ^transaction_index)
      )

  defp hardcoded_where_for_page_internal_transaction(query, block_number, transaction_index, index, true),
    do:
      where(
        query,
        [internal_transaction],
        internal_transaction.block_number < ^block_number or
          (internal_transaction.block_number == ^block_number and
             internal_transaction.transaction_index < ^transaction_index) or
          (internal_transaction.block_number == ^block_number and
             internal_transaction.transaction_index == ^transaction_index and internal_transaction.index < ^index)
      )

  defp for_parent_transaction(query, %Hash{byte_count: unquote(Hash.Full.byte_count())} = hash) do
    from(
      child in query,
      inner_join: transaction in assoc(child, :transaction),
      where: transaction.hash == ^hash
    )
  end

  # filter by `type` is automatically ignored if `call_type_filter` is not empty,
  # as applying both filter simultaneously have no sense
  defp filter_by_type(query, _, [_ | _]), do: query
  defp filter_by_type(query, [], _), do: query

  defp filter_by_type(query, types, _) do
    query
    |> where([internal_transaction], internal_transaction.type in ^types)
  end

  defp filter_by_call_type(query, []), do: query

  defp filter_by_call_type(query, call_types) do
    query
    |> where(
      [internal_transaction],
      internal_transaction.call_type_enum in ^call_types or internal_transaction.call_type in ^call_types
    )
  end

  @doc """
  Returns the ordered paginated list of internal transactions (consensus blocks only) from the DB with address, block preloads

  ## Options
    * `:exclude_origin_internal_transaction` - when `true`, filters out the origin sender transaction (index 0 with type :call)
    * `:paging_options` - a `t:Explorer.PagingOptions.t/0` for pagination
    * `:transaction_hash` - optional transaction hash to filter by
    * `:api?` - whether this is an API request
  """
  @spec fetch([paging_options | api?]) :: []
  def fetch(options) do
    paging_options = Keyword.get(options, :paging_options, @default_paging_options)
    exclude_zero_index_internal_transaction = Keyword.get(options, :exclude_origin_internal_transaction, false)

    case paging_options do
      %PagingOptions{key: {0, 0}} ->
        []

      _ ->
        preloads =
          DenormalizationHelper.extend_transaction_preload([
            :block,
            [from_address: [:scam_badge, :names, :smart_contract, proxy_implementations_association()]],
            [to_address: [:scam_badge, :names, :smart_contract, proxy_implementations_association()]]
          ])

        __MODULE__
        |> where_nonpending_operation()
        |> maybe_filter_origin_transaction(exclude_zero_index_internal_transaction)
        |> page_internal_transaction(paging_options, %{index_internal_transaction_desc_order: true})
        |> where_internal_transactions_by_transaction_hash(Keyword.get(options, :transaction_hash))
        |> order_by([internal_transaction],
          desc: internal_transaction.block_number,
          desc: internal_transaction.transaction_index,
          desc: internal_transaction.index
        )
        |> limit(^paging_options.page_size)
        |> preload(^preloads)
        |> Chain.select_repo(options).all()
        |> preload_error(options)
    end
  end

  defp page_block_internal_transaction(query, %PagingOptions{key: %{block_index: block_index}}) do
    query
    |> where([internal_transaction], internal_transaction.block_index > ^block_index)
  end

  defp page_block_internal_transaction(query, %PagingOptions{key: %{transaction_index: transaction_index, index: index}}) do
    query
    |> where(
      [internal_transaction],
      (internal_transaction.transaction_index == ^transaction_index and internal_transaction.index > ^index) or
        internal_transaction.transaction_index > ^transaction_index
    )
  end

  defp page_block_internal_transaction(query, _), do: query

  def internal_transaction_to_block_paging_options(%__MODULE__{
        transaction_index: transaction_index,
        index: index,
        block_index: block_index
      }) do
    if InternalTransactionHelper.primary_key_updated?() do
      %{"transaction_index" => transaction_index, "index" => index}
    else
      %{"block_index" => block_index}
    end
  end

  defp where_internal_transactions_by_transaction_hash(query, nil), do: query

  defp where_internal_transactions_by_transaction_hash(query, transaction_hash) do
    query
    |> where([internal_transaction], internal_transaction.transaction_hash == ^transaction_hash)
  end

  defp maybe_filter_origin_transaction(query, true), do: where_is_different_from_parent_transaction(query)
  defp maybe_filter_origin_transaction(query, false), do: query

  @doc """
  Conditionally filters internal transactions to include or exclude zero-value transfers.

  When `include_zero` is `true`, the query remains unchanged and will return all
  internal transactions regardless of their value. When `include_zero` is `false`,
  the query is modified to exclude internal transactions where the transferred
  value is zero, returning only transactions with positive Wei values.

  ## Parameters
  - `query`: An Ecto query for internal transactions
  - `include_zero`: Whether to include zero-value internal transactions

  ## Returns
  - Modified Ecto query that either includes or excludes zero-value transfers
  """
  @spec include_zero_value(Ecto.Query.t(), boolean()) :: Ecto.Query.t()
  def include_zero_value(query, true), do: query

  def include_zero_value(query, false) do
    where(
      query,
      [internal_transaction],
      (internal_transaction.type == :call and internal_transaction.value > ^0) or internal_transaction.type != :call
    )
  end

  @doc """
  Fetches and formats the first internal transaction trace for the given transaction parameters from the EthereumJSONRPC.

  This function retrieves the first trace by delegating to
  EthereumJSONRPC.fetch_first_trace and then formats the result into a
  structure suitable for insertion into the database, including type
  conversions and block index calculation.

  ## Parameters
  - `transactions_params`: List of transaction parameter maps containing
    block_hash, block_number, hash_data, and transaction_index
  - `json_rpc_named_arguments`: Named arguments for the JSON RPC call

  ## Returns
  - `{:ok, [formatted_trace]}` if the trace is successfully fetched and
    formatted
  - `{:error, reason}` if there's an error fetching the trace
  - `:ignore` if the trace should be ignored
  """
  @spec fetch_first_trace(list(map()), keyword()) :: {:ok, [map()]} | {:error, term()} | :ignore
  def fetch_first_trace(transactions_params, json_rpc_named_arguments) do
    case EthereumJSONRPC.fetch_first_trace(transactions_params, json_rpc_named_arguments) do
      {:ok, [%{first_trace: first_trace, block_hash: block_hash, block_number: block_number}]} ->
        format_transaction_first_trace(first_trace, block_hash, block_number)

      {:error, error} ->
        {:error, error}

      :ignore ->
        :ignore
    end
  end

  defp format_transaction_first_trace(first_trace, block_hash, block_number) do
    {:ok, to_address_hash} =
      if Map.has_key?(first_trace, :to_address_hash) do
        Chain.string_to_address_hash(first_trace.to_address_hash)
      else
        {:ok, nil}
      end

    {:ok, from_address_hash} = Chain.string_to_address_hash(first_trace.from_address_hash)

    {:ok, created_contract_address_hash} =
      if Map.has_key?(first_trace, :created_contract_address_hash) do
        Chain.string_to_address_hash(first_trace.created_contract_address_hash)
      else
        {:ok, nil}
      end

    {:ok, transaction_hash} = Chain.string_to_full_hash(first_trace.transaction_hash)

    {:ok, call_type} =
      if Map.has_key?(first_trace, :call_type) do
        CallType.load(first_trace.call_type)
      else
        {:ok, nil}
      end

    {:ok, type} = Type.load(first_trace.type)

    {:ok, input} =
      if Map.has_key?(first_trace, :input) do
        Data.cast(first_trace.input)
      else
        {:ok, nil}
      end

    {:ok, output} =
      if Map.has_key?(first_trace, :output) do
        Data.cast(first_trace.output)
      else
        {:ok, nil}
      end

    {:ok, created_contract_code} =
      if Map.has_key?(first_trace, :created_contract_code) do
        Data.cast(first_trace.created_contract_code)
      else
        {:ok, nil}
      end

    {:ok, init} =
      if Map.has_key?(first_trace, :init) do
        Data.cast(first_trace.init)
      else
        {:ok, nil}
      end

    value =
      if is_nil(first_trace.value), do: %Wei{value: Decimal.new("0")}, else: %Wei{value: Decimal.new(first_trace.value)}

    first_trace_formatted =
      first_trace
      |> Map.merge(%{
        block_hash: block_hash,
        block_number: block_number,
        call_type: call_type,
        to_address_hash: to_address_hash,
        created_contract_address_hash: created_contract_address_hash,
        from_address_hash: from_address_hash,
        input: input,
        output: output,
        created_contract_code: created_contract_code,
        init: init,
        transaction_hash: transaction_hash,
        type: type,
        value: value
      })

    {:ok, [first_trace_formatted]}
  end

  @spec call_type(map()) :: atom() | nil
  def call_type(%{call_type: call_type, call_type_enum: call_type_enum}) do
    if BackgroundMigrations.get_empty_internal_transactions_data_finished() do
      call_type_enum
    else
      call_type_enum || call_type
    end
  end

  @doc """
  Fills internal transaction `error` field based on `error_id`
  """
  @spec preload_error(__MODULE__.t() | [__MODULE__.t()], Keyword.t()) :: __MODULE__.t() | [__MODULE__.t()]
  def preload_error(internal_transactions, options \\ [api?: true])

  def preload_error(internal_transactions, options) when is_list(internal_transactions) do
    error_ids =
      internal_transactions
      |> Enum.filter(&is_nil(&1.error))
      |> Enum.map(& &1.error_id)
      |> Enum.uniq()
      |> Enum.reject(&is_nil/1)

    if error_ids == [] do
      internal_transactions
    else
      error_id_to_error_map =
        TransactionError
        |> where([te], te.id in ^error_ids)
        |> select([te], {te.id, te.message})
        |> Chain.select_repo(options).all()
        |> Map.new()

      Enum.map(internal_transactions, &Map.put(&1, :error, &1.error || error_id_to_error_map[&1.error_id]))
    end
  end

  def preload_error(internal_transaction, options) do
    [internal_transaction]
    |> preload_error(options)
    |> List.first()
  end
end
