defmodule Explorer.Chain.Block do
  @moduledoc """
  A package of data that contains zero or more transactions, the hash of the previous block ("parent"), and optionally
  other data. Because each block (except for the initial "genesis block") points to the previous block, the data
  structure that they form is called a "blockchain".
  """

  use Explorer.Schema

  alias Explorer.Chain.{BlockTransaction, Hash, Transaction}

  # Types

  @typedoc """
  How much work is required to find a hash with some number of leading 0s.  It is measured in hashes for PoW
  (Proof-of-Work) chains like Ethereum.  In PoA (Proof-of-Authority) chains, it does not apply as blocks are validated
  in a round-robin fashion, and so the value is always `Decimal.new(0)`.
  """
  @type difficulty :: Decimal.t()

  @typedoc """
  A measurement roughly equivalent to computational steps.  Every operation has a gas expenditure; for most operations
  it is ~3-10, although some expensive operations have expenditures up to 700 and a transaction itself has an
  expenditure of 21000.
  """
  @type gas :: non_neg_integer()

  @typedoc """
  Number of the block in the chain.
  """
  @type block_number :: non_neg_integer()

  @typedoc """
  * `block_transactions` - The `t:Explorer.Chain.BlockTransaction.t/0`s joins this block to its `transactions`
  * `difficulty` - how hard the block was to mine.
  * `gas_limit` - If the total number of gas used by the computation spawned by the transaction, including the original
      message and any sub-messages that may be triggered, is less than or equal to the gas limit, then the transaction
      processes. If the total gas exceeds the gas limit, then all changes are reverted, except that the transaction is
      still valid and the fee can still be collected by the miner.
  * `gas_used` - The actual `t:gas/0` used to mine/validate the transactions in the block.
  * `hash` - the hash of the block.
  * `miner` - the hash of the `t:Explorer.Address.t/0` of the miner.  In Proof-of-Authority chains, this is the
      validator.
  * `nonce` - the hash of the generated proof-of-work.  Not used in Proof-of-Authority chains.
  * `number` - which block this is along the chain.
  * `parent_hash` - the hash of the parent block, which should have the previous `number`
  * `size` - The size of the block in bytes.
  * `timestamp` - When the block was collated
  * `total_diffficulty` - the total `difficulty` of the chain until this block.
  * `transactions` - the `t:Explorer.Chain.Transaction.t/0` in this block.
  """
  @type t :: %__MODULE__{
          block_transactions: %Ecto.Association.NotLoaded{} | [BlockTransaction.t()],
          difficulty: difficulty(),
          gas_limit: gas(),
          gas_used: gas(),
          hash: Hash.t(),
          miner: Address.hash(),
          nonce: Hash.t(),
          number: block_number(),
          parent_hash: Hash.t(),
          size: non_neg_integer(),
          timestamp: DateTime.t(),
          total_difficulty: difficulty(),
          transactions: %Ecto.Association.NotLoaded{} | [Transaction.t()]
        }

  schema "blocks" do
    field(:difficulty, :decimal)
    field(:gas_limit, :integer)
    field(:gas_used, :integer)
    field(:hash, :string)
    field(:miner, :string)
    field(:nonce, :string)
    field(:number, :integer)
    field(:parent_hash, :string)
    field(:size, :integer)
    field(:timestamp, Timex.Ecto.DateTime)
    field(:total_difficulty, :decimal)

    timestamps()

    has_many(:block_transactions, BlockTransaction)
    many_to_many(:transactions, Transaction, join_through: "block_transactions")
  end

  @required_attrs ~w(number hash parent_hash nonce miner difficulty
                     total_difficulty size gas_limit gas_used timestamp)a

  @doc false
  def changeset(%__MODULE__{} = block, attrs) do
    block
    |> cast(attrs, @required_attrs)
    |> validate_required(@required_attrs)
    |> update_change(:hash, &String.downcase/1)
    |> unique_constraint(:hash)
    |> cast_assoc(:transactions)
  end

  def null, do: %__MODULE__{number: -1, timestamp: :calendar.universal_time()}

  def latest(query) do
    query |> order_by(desc: :number)
  end
end
