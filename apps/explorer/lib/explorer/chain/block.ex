defmodule Explorer.Chain.Block.Schema do
  @moduledoc false

  alias Explorer.Chain.{Address, Block, Hash, PendingBlockOperation, Transaction, Wei, Withdrawal}
  alias Explorer.Chain.Block.{Reward, SecondDegreeRelation}

  @chain_type_fields (case Application.compile_env(:explorer, :chain_type) do
                        "ethereum" ->
                          elem(
                            quote do
                              field(:blob_gas_used, :decimal)
                              field(:excess_blob_gas, :decimal)
                            end,
                            2
                          )

                        "rsk" ->
                          elem(
                            quote do
                              field(:bitcoin_merged_mining_header, :binary)
                              field(:bitcoin_merged_mining_coinbase_transaction, :binary)
                              field(:bitcoin_merged_mining_merkle_proof, :binary)
                              field(:hash_for_merged_mining, :binary)
                              field(:minimum_gas_price, :decimal)
                            end,
                            2
                          )

                        _ ->
                          []
                      end)

  defmacro generate do
    quote do
      @primary_key false
      typed_schema "blocks" do
        field(:hash, Hash.Full, primary_key: true, null: false)
        field(:consensus, :boolean, null: false)
        field(:difficulty, :decimal)
        field(:gas_limit, :decimal, null: false)
        field(:gas_used, :decimal, null: false)
        field(:nonce, Hash.Nonce, null: false)
        field(:number, :integer, null: false)
        field(:size, :integer)
        field(:timestamp, :utc_datetime_usec, null: false)
        field(:total_difficulty, :decimal)
        field(:refetch_needed, :boolean)
        field(:base_fee_per_gas, Wei)
        field(:is_empty, :boolean)

        timestamps()

        belongs_to(:miner, Address, foreign_key: :miner_hash, references: :hash, type: Hash.Address, null: false)

        has_many(:nephew_relations, SecondDegreeRelation, foreign_key: :uncle_hash, references: :hash)
        has_many(:nephews, through: [:nephew_relations, :nephew], references: :hash)

        belongs_to(:parent, Block, foreign_key: :parent_hash, references: :hash, type: Hash.Full, null: false)

        has_many(:uncle_relations, SecondDegreeRelation, foreign_key: :nephew_hash, references: :hash)
        has_many(:uncles, through: [:uncle_relations, :uncle], references: :hash)

        has_many(:transactions, Transaction, references: :hash)
        has_many(:transaction_forks, Transaction.Fork, foreign_key: :uncle_hash, references: :hash)

        has_many(:rewards, Reward, foreign_key: :block_hash, references: :hash)

        has_many(:withdrawals, Withdrawal, foreign_key: :block_hash, references: :hash)

        has_one(:pending_operations, PendingBlockOperation, foreign_key: :block_hash, references: :hash)

        unquote_splicing(@chain_type_fields)
      end
    end
  end
end

defmodule Explorer.Chain.Block do
  @moduledoc """
  A package of data that contains zero or more transactions, the hash of the previous block ("parent"), and optionally
  other data. Because each block (except for the initial "genesis block") points to the previous block, the data
  structure that they form is called a "blockchain".
  """

  require Explorer.Chain.Block.Schema

  use Explorer.Schema

  alias Explorer.Chain.{Block, Hash, Transaction, Wei}
  alias Explorer.Chain.Block.{EmissionReward, Reward}
  alias Explorer.Repo

  @optional_attrs ~w(size refetch_needed total_difficulty difficulty base_fee_per_gas)a
                  |> (&(case Application.compile_env(:explorer, :chain_type) do
                          "rsk" ->
                            &1 ++
                              ~w(minimum_gas_price bitcoin_merged_mining_header bitcoin_merged_mining_coinbase_transaction bitcoin_merged_mining_merkle_proof hash_for_merged_mining)a

                          "ethereum" ->
                            &1 ++
                              ~w(blob_gas_used excess_blob_gas)a

                          _ ->
                            &1
                        end)).()

  @required_attrs ~w(consensus gas_limit gas_used hash miner_hash nonce number parent_hash timestamp)a

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
  #{case Application.compile_env(:explorer, :chain_type) do
    "rsk" -> """
       * `bitcoin_merged_mining_header` - Bitcoin merged mining header on Rootstock chains.
       * `bitcoin_merged_mining_coinbase_transaction` - Bitcoin merged mining coinbase transaction on Rootstock chains.
       * `bitcoin_merged_mining_merkle_proof` - Bitcoin merged mining merkle proof on Rootstock chains.
       * `hash_for_merged_mining` - Hash for merged mining on Rootstock chains.
       * `minimum_gas_price` - Minimum block gas price on Rootstock chains.
      """
    "ethereum" -> """
       * `blob_gas_used` - The total amount of blob gas consumed by the transactions within the block.
       * `excess_blob_gas` - The running total of blob gas consumed in excess of the target, prior to the block.
      """
    _ -> ""
  end}
  """
  Explorer.Chain.Block.Schema.generate()

  def changeset(%__MODULE__{} = block, attrs) do
    block
    |> cast(attrs, @required_attrs ++ @optional_attrs)
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
        block in __MODULE__,
        where: block.consensus == true
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
    from(block in query,
      as: :block,
      left_join: uncles in assoc(block, :nephew_relations),
      where:
        block.consensus == false and is_nil(uncles.uncle_hash) and
          exists(from(b in Block, where: b.number == parent_as(:block).number and b.consensus))
    )
  end

  def block_type_filter(query, "Uncle"), do: where(query, [block], block.consensus == false)

  @doc """
  Returns query that fetches up to `limit` of consensus blocks
  that are missing rootstock data ordered by number desc.
  """
  @spec blocks_without_rootstock_data_query(non_neg_integer()) :: Ecto.Query.t()
  def blocks_without_rootstock_data_query(limit) do
    from(
      block in __MODULE__,
      where:
        is_nil(block.minimum_gas_price) or
          is_nil(block.bitcoin_merged_mining_header) or
          is_nil(block.bitcoin_merged_mining_coinbase_transaction) or
          is_nil(block.bitcoin_merged_mining_merkle_proof) or
          is_nil(block.hash_for_merged_mining),
      where: block.consensus == true,
      limit: ^limit,
      order_by: [desc: block.number]
    )
  end

  @doc """
  Calculates transaction fees (gas price * gas used) for the list of transactions (from a single block)
  """
  @spec transaction_fees([Transaction.t()]) :: Decimal.t()
  def transaction_fees(transactions) do
    Enum.reduce(transactions, Decimal.new(0), fn %{gas_used: gas_used, gas_price: gas_price}, acc ->
      if gas_price do
        gas_used
        |> Decimal.new()
        |> Decimal.mult(gas_price_to_decimal(gas_price))
        |> Decimal.add(acc)
      else
        acc
      end
    end)
  end

  @doc """
  Finds blob transaction gas price for the list of transactions (from a single block)
  """
  @spec transaction_blob_gas_price([Transaction.t()]) :: Decimal.t() | nil
  def transaction_blob_gas_price(transactions) do
    transactions
    |> Enum.find_value(fn %{beacon_blob_transaction: beacon_blob_transaction} ->
      if is_nil(beacon_blob_transaction) do
        nil
      else
        gas_price_to_decimal(beacon_blob_transaction.blob_gas_price)
      end
    end)
  end

  defp gas_price_to_decimal(nil), do: nil
  defp gas_price_to_decimal(%Wei{} = wei), do: wei.value
  defp gas_price_to_decimal(gas_price), do: Decimal.new(gas_price)

  @doc """
  Calculates burnt fees for the list of transactions (from a single block)
  """
  @spec burnt_fees(list(), Decimal.t() | nil) :: Decimal.t()
  def burnt_fees(transactions, base_fee_per_gas) do
    if is_nil(base_fee_per_gas) do
      Decimal.new(0)
    else
      transactions
      |> Enum.reduce(Decimal.new(0), fn %{gas_used: gas_used}, acc ->
        gas_used
        |> Decimal.new()
        |> Decimal.add(acc)
      end)
      |> Decimal.mult(gas_price_to_decimal(base_fee_per_gas))
    end
  end

  @uncle_reward_coef 32
  @spec block_reward_by_parts(Block.t(), [Transaction.t()]) :: %{
          block_number: block_number(),
          block_hash: Hash.Full.t(),
          miner_hash: Hash.Address.t(),
          static_reward: any(),
          transaction_fees: any(),
          burnt_fees: Wei.t() | nil,
          uncle_reward: Wei.t()
        }
  def block_reward_by_parts(block, transactions) do
    %{hash: block_hash, number: block_number} = block
    base_fee_per_gas = Map.get(block, :base_fee_per_gas)

    transaction_fees = transaction_fees(transactions)

    static_reward =
      Repo.one(
        from(
          er in EmissionReward,
          where: fragment("int8range(?, ?) <@ ?", ^block_number, ^(block_number + 1), er.block_range),
          select: er.reward
        )
      ) || %Wei{value: Decimal.new(0)}

    uncles_count = if is_list(block.uncles), do: Enum.count(block.uncles), else: 0

    burnt_fees = burnt_fees(transactions, base_fee_per_gas)
    uncle_reward = static_reward |> Wei.div(@uncle_reward_coef) |> Wei.mult(uncles_count)

    # eip4844 blob transactions don't impact validator rewards, so we don't count them here as part of transaction_fees and burnt_fees
    %{
      block_number: block_number,
      block_hash: block_hash,
      miner_hash: block.miner_hash,
      static_reward: static_reward,
      transaction_fees: %Wei{value: transaction_fees},
      burnt_fees: %Wei{value: burnt_fees},
      uncle_reward: uncle_reward
    }
  end

  def uncle_reward_coef, do: @uncle_reward_coef

  @doc """
  Calculates the gas target for a given block.

  The gas target represents the percentage by which the actual gas used is above or below the gas target for the block, adjusted by the elasticity multiplier.
  If the `gas_limit` is greater than 0, it calculates the ratio of `gas_used` to `gas_limit` adjusted by this multiplier.
  """
  @spec gas_target(t()) :: float()
  def gas_target(block) do
    if Decimal.compare(block.gas_limit, 0) == :gt do
      elasticity_multiplier = Application.get_env(:explorer, :elasticity_multiplier)
      ratio = Decimal.div(block.gas_used, Decimal.div(block.gas_limit, elasticity_multiplier))
      ratio |> Decimal.sub(1) |> Decimal.mult(100) |> Decimal.to_float()
    else
      0.0
    end
  end

  @doc """
  Calculates the percentage of gas used for a given block relative to its gas limit.

  This function determines what percentage of the block's gas limit was actually used by the transactions in the block.
  """
  @spec gas_used_percentage(t()) :: float()
  def gas_used_percentage(block) do
    if Decimal.compare(block.gas_limit, 0) == :gt do
      block.gas_used |> Decimal.div(block.gas_limit) |> Decimal.mult(100) |> Decimal.to_float()
    else
      0.0
    end
  end

  @doc """
  Calculates the base fee for the next block based on the current block's gas usage.

  The base fee calculation uses the following [formula](https://eips.ethereum.org/EIPS/eip-1559):

      gas_target = gas_limit / elasticity_multiplier
      base_fee_for_next_block = base_fee_per_gas + (base_fee_per_gas * gas_used_delta / gas_target / base_fee_max_change_denominator)

  where elasticity_multiplier is an env variable `EIP_1559_ELASTICITY_MULTIPLIER`,
  `gas_used_delta` is the difference between the actual gas used and the target gas
  and `base_fee_max_change_denominator` is an env variable `EIP_1559_BASE_FEE_MAX_CHANGE_DENOMINATOR` that limits the maximum change of the base fee from one block to the next.


  """
  @spec next_block_base_fee_per_gas :: Decimal.t() | nil
  def next_block_base_fee_per_gas do
    query =
      from(block in Block,
        where: block.consensus == true,
        order_by: [desc: block.number],
        limit: 1
      )

    case Repo.one(query) do
      nil -> nil
      block -> next_block_base_fee_per_gas(block)
    end
  end

  @spec next_block_base_fee_per_gas(t()) :: Decimal.t() | nil
  def next_block_base_fee_per_gas(block) do
    elasticity_multiplier = Application.get_env(:explorer, :elasticity_multiplier)
    base_fee_max_change_denominator = Application.get_env(:explorer, :base_fee_max_change_denominator)

    gas_target = Decimal.div(block.gas_limit, elasticity_multiplier)

    gas_used_delta = Decimal.sub(block.gas_used, gas_target)

    base_fee_per_gas_decimal = block.base_fee_per_gas |> Wei.to(:wei)

    base_fee_per_gas_decimal &&
      base_fee_per_gas_decimal
      |> Decimal.mult(gas_used_delta)
      |> Decimal.div(gas_target)
      |> Decimal.div(base_fee_max_change_denominator)
      |> Decimal.add(base_fee_per_gas_decimal)
  end
end
