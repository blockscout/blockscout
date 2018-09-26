defmodule Explorer.Chain.Block do
  @moduledoc """
  A package of data that contains zero or more transactions, the hash of the previous block ("parent"), and optionally
  other data. Because each block (except for the initial "genesis block") points to the previous block, the data
  structure that they form is called a "blockchain".
  """

  use Explorer.Schema

  alias Explorer.Chain.{Address, Block.SecondDegreeRelation, Gas, Hash, Transaction}

  @required_attrs ~w(consensus difficulty gas_limit gas_used hash miner_hash nonce number parent_hash size timestamp
                     total_difficulty)a

  @typedoc """
  How much work is required to find a hash with some number of leading 0s.  It is measured in hashes for PoW
  (Proof-of-Work) chains like Ethereum.  In PoA (Proof-of-Authority) chains, it does not apply as blocks are validated
  in a round-robin fashion, and so the value is always `Decimal.new(0)`.
  """
  @type difficulty :: Decimal.t()

  @typedoc """
  Number of the block in the chain.
  """
  @type block_number :: non_neg_integer()

  @typedoc """
   * `consensus`
     * `true` - this is a block on the longest consensus agreed upon chain.
     * `false` - this is an uncle block from a fork.
   * `difficulty` - how hard the block was to mine.
   * `gas_limit` - If the total number of gas used by the computation spawned by the transaction, including the
     original message and any sub-messages that may be triggered, is less than or equal to the gas limit, then the
     transaction processes. If the total gas exceeds the gas limit, then all changes are reverted, except that the
     transaction is still valid and the fee can still be collected by the miner.
   * `gas_used` - The actual `t:gas/0` used to mine/validate the transactions in the block.
   * `hash` - the hash of the block.
   * `miner` - the hash of the `t:Explorer.Chain.Address.t/0` of the miner.  In Proof-of-Authority chains, this is the
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
          consensus: boolean(),
          difficulty: difficulty(),
          gas_limit: Gas.t(),
          gas_used: Gas.t(),
          hash: Hash.Full.t(),
          miner: %Ecto.Association.NotLoaded{} | Address.t(),
          miner_hash: Hash.Address.t(),
          nonce: Hash.Nonce.t(),
          number: block_number(),
          parent_hash: Hash.t(),
          size: non_neg_integer(),
          timestamp: DateTime.t(),
          total_difficulty: difficulty(),
          transactions: %Ecto.Association.NotLoaded{} | [Transaction.t()]
        }

  @primary_key {:hash, Hash.Full, autogenerate: false}
  schema "blocks" do
    field(:consensus, :boolean)
    field(:difficulty, :decimal)
    field(:gas_limit, :decimal)
    field(:gas_used, :decimal)
    field(:nonce, Hash.Nonce)
    field(:number, :integer)
    field(:size, :integer)
    field(:timestamp, :utc_datetime)
    field(:total_difficulty, :decimal)

    timestamps()

    belongs_to(:miner, Address, foreign_key: :miner_hash, references: :hash, type: Hash.Address)

    has_many(:nephew_relations, SecondDegreeRelation, foreign_key: :uncle_hash)
    has_many(:nephews, through: [:nephew_relations, :nephew])

    belongs_to(:parent, __MODULE__, foreign_key: :parent_hash, references: :hash, type: Hash.Full)

    has_many(:uncle_relations, SecondDegreeRelation, foreign_key: :nephew_hash)
    has_many(:uncles, through: [:uncle_relations, :uncle])

    has_many(:transactions, Transaction)
  end

  def changeset(%__MODULE__{} = block, attrs) do
    block
    |> cast(attrs, @required_attrs)
    |> validate_required(@required_attrs)
    |> foreign_key_constraint(:parent_hash)
    |> unique_constraint(:hash, name: :blocks_pkey)
  end
end
