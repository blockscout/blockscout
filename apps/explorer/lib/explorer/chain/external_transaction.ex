defmodule Explorer.Chain.ExternalTransaction do
  @moduledoc "Models external transactions."

  use Explorer.Schema

  alias Explorer.Chain.{Address, Block, Data, Gas, Hash, PendingBlockOperation, Transaction, Wei}
  alias Explorer.Chain.ExternalTransaction.{Action, CallType, Result, Type}
  alias Explorer.Chain.Transaction.{Fork, Status}
  @type wei_per_gas :: Wei.t()
  @type transaction_index :: non_neg_integer()
  @type r :: Decimal.t()
  @type s :: Decimal.t()
  @type v :: 27..30

  @typedoc """
   * `block_number` - the `t:Explorer.Chain.Block.t/0` `number` that the `transaction` is collated into.
   * `call_type` - the type of call.  `nil` when `type` is not `:call`.
   * `created_contract_code` - the code of the contract that was created when `type` is `:create`.
   * `error` - error message when `:call` or `:create` `type` errors
   * `from_address` - the source of the `value`
   * `from_address_hash` - hash of the source of the `value`
   * `gas` - the amount of gas allowed
   * `gas_used` - the amount of gas used.  `nil` when a call errors.
   * `index` - the index of this external transaction inside the `transaction`
   * `init` - the constructor arguments for creating `created_contract_code` when `type` is `:create`.
   * `input` - input bytes to the call
   * `output` - output bytes from the call.  `nil` when a call errors.
   * `to_address` - the sink of the `value`
   * `to_address_hash` - hash of the sink of the `value`
   * `trace_address` - list of traces
   * `transaction` - transaction in which this external transaction occurred
   * `transaction_hash` - foreign key for `transaction`
   * `transaction_index` - the `t:Explorer.Chain.Transaction.t/0` `index` of `transaction` in `block_number`.
   * `type` - type of external transaction
   * `value` - value of transferred from `from_address` to `to_address`
   * `block` - block in which this external transaction occurred
   * `block_hash` - foreign key for `block`
   * `block_index` - the index of this external transaction inside the `block`
   * `pending_block` - `nil` if `block` has all its external transactions fetched
  """
  @type t :: %__MODULE__{
           block: %Ecto.Association.NotLoaded{} | Block.t() | nil,
           block_hash: Hash.t() | nil,
           block_number: Block.block_number() | nil,
           created_contract_address: %Ecto.Association.NotLoaded{} | Address.t() | nil,
           created_contract_address_hash: Hash.Address.t() | nil,
           created_contract_code_indexed_at: DateTime.t() | nil,
           cumulative_gas_used: Gas.t() | nil,
           earliest_processing_start: DateTime.t() | nil,
           error: String.t() | nil,
           from_address: %Ecto.Association.NotLoaded{} | Address.t(),
           from_address_hash: Hash.Address.t(),
           gas: Gas.t(),
           gas_price: wei_per_gas,
           gas_used: Gas.t() | nil,
           hash: Hash.t(),
           index: transaction_index | nil,
           input: Data.t(),
           nonce: non_neg_integer(),
           r: r(),
           s: s(),
           status: Status.t() | nil,
           to_address: %Ecto.Association.NotLoaded{} | Address.t() | nil,
           to_address_hash: Hash.Address.t() | nil,
           v: v(),
           value: Wei.t(),
           revert_reason: String.t() | nil,
           max_priority_fee_per_gas: wei_per_gas | nil,
           max_fee_per_gas: wei_per_gas | nil,
           type: non_neg_integer() | nil,
  }

  @primary_key {:hash, Hash.Full, autogenerate: false}
  schema "external_transactions" do
    field(:block_number, :integer)
    field(:cumulative_gas_used, :decimal)
    field(:earliest_processing_start, :utc_datetime_usec)
    field(:error, :string)
    field(:gas, :decimal)
    field(:gas_price, Wei)
    field(:gas_used, :decimal)
    field(:index, :integer)
    field(:created_contract_code_indexed_at, :utc_datetime_usec)
    field(:input, Data)
    field(:nonce, :integer)
    field(:r, :decimal)
    field(:s, :decimal)
    field(:status, Status)
    field(:v, :decimal)
    field(:value, Wei)
    field(:revert_reason, :string)
    field(:max_priority_fee_per_gas, Wei)
    field(:max_fee_per_gas, Wei)
    field(:type, :integer)

    # A transient field for deriving old block hash during transaction upserts.
    # Used to force refetch of a block in case a transaction is re-collated
    # in a different block. See: https://github.com/blockscout/blockscout/issues/1911
    field(:old_block_hash, Hash.Full)

    timestamps()

    belongs_to(:block, Block, foreign_key: :block_hash, references: :hash, type: Hash.Full)

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

    belongs_to(
      :created_contract_address,
      Address,
      foreign_key: :created_contract_address_hash,
      references: :hash,
      type: Hash.Address
    )
  end

  @doc """
  Validates that the `attrs` are valid.

  `:create` type traces generated when a contract is created are valid.  `created_contract_address_hash`,
  `from_address_hash`, and `transaction_hash` are converted to `t:Explorer.Chain.Hash.t/0`, and `type` is converted to
  `t:Explorer.Chain.ExternalTransaction.Type.t/0`

      iex> changeset = Explorer.Chain.ExternalTransaction.changeset(
      ...>   %Explorer.Chain.ExternalTransaction{},
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
      ...>     block_number: 35,
      ...>     block_hash: "0xf6b4b8c88df3ebd252ec476328334dc026cf66606a84fb769b3d3cbccc8471bd",
      ...>     block_index: 0
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

      iex> changeset = Explorer.Chain.ExternalTransaction.changeset(
      ...>   %Explorer.Chain.ExternalTransaction{},
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
      ...>     block_index: 0,
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

      iex> changeset = Explorer.Chain.ExternalTransaction.changeset(
      ...>   %Explorer.Chain.ExternalTransaction{},
      ...>   %{
      ...>     block_number: 35,
      ...>     block_hash: "0xf6b4b8c88df3ebd252ec476328334dc026cf66606a84fb769b3d3cbccc8471bd",
      ...>     block_index: 0,
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

      iex> changeset = Explorer.Chain.ExternalTransaction.changeset(
      ...>   %Explorer.Chain.ExternalTransaction{},
      ...>   %{
      ...>     block_number: 35,
      ...>     block_hash: "0xf6b4b8c88df3ebd252ec476328334dc026cf66606a84fb769b3d3cbccc8471bd",
      ...>     block_index: 0,
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

      iex> changeset = Explorer.Chain.ExternalTransaction.changeset(
      ...>   %Explorer.Chain.ExternalTransaction{},
      ...>   %{
      ...>     block_number: 35,
      ...>     block_hash: "0xf6b4b8c88df3ebd252ec476328334dc026cf66606a84fb769b3d3cbccc8471bd",
      ...>     block_index: 0,
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
      false
      iex> changeset.errors
      [
        output: {"can't be present for failed call", []}
      ]

  Likewise, successful `:call`s require `input`, `gas_used` and `output` to be set.

      iex> changeset = Explorer.Chain.ExternalTransaction.changeset(
      ...>   %Explorer.Chain.ExternalTransaction{},
      ...>   %{
      ...>     block_number: 35,
      ...>     block_hash: "0xf6b4b8c88df3ebd252ec476328334dc026cf66606a84fb769b3d3cbccc8471bd",
      ...>     block_index: 0,
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

      iex> changeset = Explorer.Chain.ExternalTransaction.changeset(
      ...>   %Explorer.Chain.ExternalTransaction{},
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
      ...>     block_index: 0,
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

      iex> changeset = Explorer.Chain.ExternalTransaction.changeset(
      ...>   %Explorer.Chain.ExternalTransaction{},
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
      ...>     block_index: 0,
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

      iex> changeset = Explorer.Chain.ExternalTransaction.changeset(
      ...>   %Explorer.Chain.ExternalTransaction{},
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
      ...>     block_index: 0,
      ...>     transaction_index: 0
      ...>   }
      ...> )
      iex> changeset.valid?
      true

  """

  def changeset(%__MODULE__{} = external_transaction, attrs \\ %{}) do
    external_transaction
    |> cast(attrs, ~w(block_hash block_number from_address_hash gas gas_price max_fee_per_gas max_priority_fee_per_gas hash input nonce to_address_hash index value type v r s)a)
    |> validate_required(~w()a)
    |> validate_block_required(attrs)
  end

  @doc """
  Accepts changes without `:type` but with `:block_number`, if `:type` is defined
  works like `changeset`, except allowing `:block_hash` and `:block_index` to be undefined.

  This is used because the `external_transactions` runner can derive such values
  on its own or use empty types to know that a block has no external transactions.
  """
  def blockless_changeset(%__MODULE__{} = external_transaction, attrs \\ %{}) do
    cast(external_transaction, attrs, ~w(block_number)a)
  end

  defp validate_block_required(changeset, attrs) do
    changeset
    |> cast(attrs, ~w(block_hash index block_number )a)
    |> validate_required(~w(block_hash index)a)
    |> foreign_key_constraint(:block_hash)
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

  # Validates that :call `type` changeset either has an `error` or both `gas_used` and `output`
  defp validate_call_error_or_result(changeset) do
    case get_field(changeset, :error) do
      nil -> validate_required(changeset, [:gas_used, :output], message: "can't be blank for successful call")
      _ -> validate_disallowed(changeset, [:output], message: "can't be present for failed call")
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
    from_address_hash, created_contract_address_hash from external_transactions' table.
  """
  def where_address_fields_match(query, address_hash, :to) do
    where(
      query,
      [t],
      t.to_address_hash == ^address_hash or
        (is_nil(t.to_address_hash) and t.created_contract_address_hash == ^address_hash)
    )
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

  def where_address_fields_match(query, address_hash, :to_address_hash) do
    where(query, [it], it.to_address_hash == ^address_hash)
  end

  def where_address_fields_match(query, address_hash, :from_address_hash) do
    where(query, [it], it.from_address_hash == ^address_hash)
  end

  def where_address_fields_match(query, address_hash, :created_contract_address_hash) do
    where(query, [it], it.created_contract_address_hash == ^address_hash)
  end

  def where_is_different_from_parent_transaction(query) do
    where(
      query,
      [it],
      (it.type == ^:call and it.index > 0) or it.type != ^:call
    )
  end

  def where_block_number_in_period(query, from_number, to_number) when is_nil(from_number) and not is_nil(to_number) do
    where(
      query,
      [it],
      it.block_number <= ^to_number
    )
  end

  def where_block_number_in_period(query, from_number, to_number) when not is_nil(from_number) and is_nil(to_number) do
    where(
      query,
      [it],
      it.block_number > ^from_number
    )
  end

  def where_block_number_in_period(query, from_number, to_number) when is_nil(from_number) and is_nil(to_number) do
    where(
      query,
      [it],
      1
    )
  end

  def where_block_number_in_period(query, from_number, to_number) do
    where(
      query,
      [it],
      it.block_number > ^from_number and it.block_number <= ^to_number
    )
  end

  def where_block_number_is_not_null(query) do
    where(query, [t], not is_nil(t.block_number))
  end

  @doc """
  Filters out external_transactions of blocks that are flagged as needing fethching
  of external_transactions
  """
  def where_nonpending_block(query \\ nil) do
    (query || __MODULE__)
    |> join(:left, [it], pending in assoc(it, :pending_block), as: :pending)
    |> where([it, pending: pending], is_nil(pending.block_hash))
  end

  def external_transactions_to_raw(external_transactions) when is_list(external_transactions) do
    external_transactions
    |> Enum.map(&external_transaction_to_raw/1)
    |> add_subtraces()
  end

  defp external_transaction_to_raw(%{type: :call} = transaction) do
    %{
      call_type: call_type,
      to_address_hash: to_address_hash,
      from_address_hash: from_address_hash,
      input: input,
      gas: gas,
      value: value,
      trace_address: trace_address
    } = transaction

    action = %{
      "callType" => call_type,
      "to" => to_address_hash,
      "from" => from_address_hash,
      "input" => input,
      "gas" => gas,
      "value" => value
    }

    %{
      "type" => "call",
      "action" => Action.to_raw(action),
      "traceAddress" => trace_address
    }
    |> put_raw_call_error_or_result(transaction)
  end

  defp external_transaction_to_raw(%{type: type} = transaction) when type in [:create, :create2] do
    %{
      from_address_hash: from_address_hash,
      gas: gas,
      init: init,
      trace_address: trace_address,
      value: value
    } = transaction

    action = %{"from" => from_address_hash, "gas" => gas, "init" => init, "value" => value}

    %{
      "type" => Atom.to_string(type),
      "action" => Action.to_raw(action),
      "traceAddress" => trace_address
    }
    |> put_raw_create_error_or_result(transaction)
  end

  defp external_transaction_to_raw(%{type: :selfdestruct} = transaction) do
    %{
      to_address_hash: to_address_hash,
      from_address_hash: from_address_hash,
      trace_address: trace_address,
      value: value
    } = transaction

    action = %{
      "address" => from_address_hash,
      "balance" => value,
      "refundAddress" => to_address_hash
    }

    %{
      "type" => "suicide",
      "action" => Action.to_raw(action),
      "traceAddress" => trace_address
    }
  end

  defp add_subtraces(traces) do
    Enum.map(traces, fn trace ->
      Map.put(trace, "subtraces", count_subtraces(trace, traces))
    end)
  end

  defp count_subtraces(%{"traceAddress" => trace_address}, traces) do
    Enum.count(traces, fn %{"traceAddress" => trace_address_candidate} ->
      direct_descendant?(trace_address, trace_address_candidate)
    end)
  end

  defp direct_descendant?([], [_]), do: true

  defp direct_descendant?([elem | remaining_left], [elem | remaining_right]),
    do: direct_descendant?(remaining_left, remaining_right)

  defp direct_descendant?(_, _), do: false

  defp put_raw_call_error_or_result(raw, %{error: error}) when not is_nil(error) do
    Map.put(raw, "error", error)
  end

  defp put_raw_call_error_or_result(raw, %{gas_used: gas_used, output: output}) do
    Map.put(raw, "result", Result.to_raw(%{"gasUsed" => gas_used, "output" => output}))
  end

  defp put_raw_create_error_or_result(raw, %{error: error}) when not is_nil(error) do
    Map.put(raw, "error", error)
  end

  defp put_raw_create_error_or_result(raw, %{
         created_contract_code: code,
         created_contract_address_hash: created_contract_address_hash,
         gas_used: gas_used
       }) do
    Map.put(
      raw,
      "result",
      Result.to_raw(%{"gasUsed" => gas_used, "code" => code, "address" => created_contract_address_hash})
    )
  end
end
