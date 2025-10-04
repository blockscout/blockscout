defmodule Explorer.Chain.InternalTransactionArchive do
  @moduledoc "Models archival internal transactions."

  use Explorer.Schema

  alias Explorer.Chain.{Address, Block, Data, Hash, PendingBlockOperation, Transaction, Wei}
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
   * `transaction` - transaction in which this internal transaction occurred
   * `transaction_hash` - foreign key for `transaction`
   * `transaction_index` - the `t:Explorer.Chain.Transaction.t/0` `index` of `transaction` in `block_number`.
   * `type` - type of internal transaction
   * `value` - value of transferred from `from_address` to `to_address`
   * `block` - block in which this internal transaction occurred
   * `block_hash` - foreign key for `block`
   * `block_index` - the index of this internal transaction inside the `block`
   * `pending_block` - `nil` if `block` has all its internal transactions fetched
  """
  @primary_key false
  typed_schema "archival_internal_transactions" do
    field(:call_type, CallType)
    field(:created_contract_code, Data)
    field(:error, :string)
    field(:gas, :decimal)
    field(:gas_used, :decimal)
    field(:index, :integer, primary_key: true, null: false)
    field(:init, Data)
    field(:input, Data)
    field(:output, Data)
    field(:trace_address, {:array, :integer}, null: false)
    field(:type, Type, null: false)
    field(:value, Wei, null: false)
    field(:block_number, :integer)
    field(:transaction_index, :integer)
    field(:block_index, :integer, null: false)

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
      primary_key: true,
      references: :hash,
      type: Hash.Full,
      null: false
    )

    belongs_to(:block, Block,
      foreign_key: :block_hash,
      references: :hash,
      type: Hash.Full,
      null: false
    )

    belongs_to(:pending_block, PendingBlockOperation,
      foreign_key: :block_hash,
      define_field: false,
      references: :block_hash,
      type: Hash.Full
    )
  end

  @doc """
  Ensures the following conditions are true:

    * excludes archival internal transactions of type call with no siblings in the
      transaction
    * includes archival internal transactions of type create, reward, or selfdestruct
      even when they are alone in the parent transaction

  """
  @spec where_transaction_has_multiple_internal_transactions(Ecto.Query.t()) :: Ecto.Query.t()
  def where_transaction_has_multiple_internal_transactions(query) do
    where(
      query,
      [internal_transaction, transaction],
      internal_transaction.type != ^:call or
        fragment(
          """
          EXISTS (SELECT sibling.*
          FROM archival_internal_transactions AS sibling
          WHERE sibling.transaction_hash = ? AND sibling.index != ?
          )
          """,
          transaction.hash,
          internal_transaction.index
        )
    )
  end
end
