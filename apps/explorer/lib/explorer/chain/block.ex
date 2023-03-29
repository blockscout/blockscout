defmodule Explorer.Chain.Block do
  @moduledoc """
  A package of data that contains zero or more transactions, the hash of the previous block ("parent"), and optionally
  other data. Because each block (except for the initial "genesis block") points to the previous block, the data
  structure that they form is called a "blockchain".
  """

  use Explorer.Schema

  alias Explorer.Chain.{Address, Gas, Hash, PendingBlockOperation, Transaction, Wei}
  alias Explorer.Chain.Block.{Reward, SecondDegreeRelation}

  @optional_attrs ~w(size refetch_needed total_difficulty difficulty base_fee_per_gas)a

  @required_attrs ~w(consensus gas_limit gas_used hash miner_hash nonce number parent_hash timestamp)a

  @quai_attrs ~w(base_fee_per_gas_full difficulty_full ext_rollup_root_full ext_transactions_root_full gas_limit_full gas_used_full logs_bloom_full manifest_hash_full miner_full number_full parent_hash_full receipts_root_full sha3_uncles_full state_root_full transactions_root_full ext_transactions sub_manifest location is_prime_coincident is_region_coincident)a

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
   * `total_difficulty` - the total `difficulty` of the chain until this block.
   * `transactions` - the `t:Explorer.Chain.Transaction.t/0` in this block.
   * `base_fee_per_gas` - Minimum fee required per unit of gas. Fee adjusts based on network congestion.
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
          transactions: %Ecto.Association.NotLoaded{} | [Transaction.t()],
          refetch_needed: boolean(),
          base_fee_per_gas: Wei.t(),
          is_empty: boolean(),
          base_fee_per_gas_full: [Wei.t()],
          difficulty_full: [difficulty()],
          ext_rollup_root_full: [Hash.Full.t()],
          ext_transactions_root_full: [Hash.Full.t()],
#          ext_transactions: [Transaction.t()],
          ext_transactions: [Hash.Full.t()],
          sub_manifest: [Hash.Full.t()],
          gas_limit_full: [Gas.t()],
          gas_used_full: [Gas.t()],
          logs_bloom_full: [Hash.Full.t()],
          manifest_hash_full: [Hash.Full.t()],
          miner_full: [Address.t()],
          number_full: [block_number()],
          parent_hash_full: [Hash.t()],
          receipts_root_full: [Hash.Full.t()],
          sha3_uncles_full: [Hash.Full.t()],
          state_root_full: [Hash.Full.t()],
          transactions_root_full: [Hash.Full.t()],
#          location: [:integer],
          location: :string,
          is_prime_coincident: boolean(),
          is_region_coincident: boolean()
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
    field(:timestamp, :utc_datetime_usec)
    field(:total_difficulty, :decimal)
    field(:refetch_needed, :boolean)
    field(:base_fee_per_gas, Wei)
    field(:is_empty, :boolean)

    field(:base_fee_per_gas_full, {:array, Wei})
    field(:difficulty_full, {:array, :decimal})
    field(:ext_rollup_root_full, {:array, Hash.Full})
    field(:ext_transactions_root_full, {:array, Hash.Full})
    field(:ext_transactions, {:array, Hash.Full})
    field(:sub_manifest, {:array, Hash.Full})
    field(:gas_limit_full, {:array, :decimal})
    field(:gas_used_full, {:array, :decimal})
    field(:logs_bloom_full, {:array, Hash.Full})
    field(:manifest_hash_full, {:array, Hash.Full})
    field(:miner_full, {:array, Hash.Address})
    field(:number_full, {:array, :integer})
    field(:parent_hash_full, {:array, Hash.Full})
    field(:receipts_root_full, {:array, Hash.Full})
    field(:sha3_uncles_full, {:array, Hash.Full})
    field(:state_root_full, {:array, Hash.Full})
    field(:transactions_root_full, {:array, Hash.Full})
    field(:location, :string)
    field(:is_prime_coincident, :boolean)
    field(:is_region_coincident, :boolean)
    timestamps()

    belongs_to(:miner, Address, foreign_key: :miner_hash, references: :hash, type: Hash.Address)

    has_many(:nephew_relations, SecondDegreeRelation, foreign_key: :uncle_hash)
    has_many(:nephews, through: [:nephew_relations, :nephew])

    belongs_to(:parent, __MODULE__, foreign_key: :parent_hash, references: :hash, type: Hash.Full)

    has_many(:uncle_relations, SecondDegreeRelation, foreign_key: :nephew_hash)
    has_many(:uncles, through: [:uncle_relations, :uncle])

    has_many(:transactions, Transaction)
#    has_many(:ext_transactions, Transaction)
    has_many(:transaction_forks, Transaction.Fork, foreign_key: :uncle_hash)

    has_many(:rewards, Reward, foreign_key: :block_hash)

    has_one(:pending_operations, PendingBlockOperation, foreign_key: :block_hash)
  end

  def changeset(%__MODULE__{} = block, attrs) do
    block
    |> cast(attrs, @required_attrs ++ @optional_attrs ++ @quai_attrs)
    |> validate_required(@required_attrs)
    |> foreign_key_constraint(:parent_hash)
    |> unique_constraint(:hash, name: :blocks_pkey)
  end

  def number_only_changeset(%__MODULE__{} = block, attrs) do
    block
    |> cast(attrs, @required_attrs ++ @optional_attrs)
    |> validate_required([:number])
    |> foreign_key_constraint(:parent_hash)
    |> unique_constraint(:hash, name: :blocks_pkey)
  end

  def blocks_without_reward_query do
    consensus_blocks_query =
      from(
        b in __MODULE__,
        where: b.consensus == true
      )

    validator_rewards =
      from(
        r in Reward,
        where: r.address_type == ^"validator"
      )

    from(
      b in subquery(consensus_blocks_query),
      left_join: r in subquery(validator_rewards),
      on: [block_hash: b.hash],
      where: is_nil(r.block_hash)
    )
  end

  @doc """
  Adds to the given block's query a `where` with conditions to filter by the type of block;
  `Uncle`, `Reorg`, or `Block`.
  """
  def block_type_filter(query, "Block"), do: where(query, [block], block.consensus == true)

  def block_type_filter(query, "Reorg") do
    query
    |> join(:left, [block], uncles in assoc(block, :nephew_relations))
    |> where([block, uncles], block.consensus == false and is_nil(uncles.uncle_hash))
  end

  def block_type_filter(query, "Uncle"), do: where(query, [block], block.consensus == false)
end
