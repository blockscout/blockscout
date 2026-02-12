defmodule Explorer.Chain.Block.Schema do
  @moduledoc """
    Models blocks.

    Changes in the schema should be reflected in the bulk import module:
    - Explorer.Chain.Import.Runner.Blocks
  """
  use Utils.CompileTimeEnvHelper,
    chain_type: [:explorer, :chain_type],
    chain_identity: [:explorer, :chain_identity]

  alias Explorer.Chain.{
    Address,
    Block,
    Hash,
    InternalTransaction,
    PendingBlockOperation,
    Transaction,
    Wei,
    Withdrawal
  }

  alias Explorer.Chain.Arbitrum.BatchBlock, as: ArbitrumBatchBlock
  alias Explorer.Chain.Beacon.Deposit, as: BeaconDeposit
  alias Explorer.Chain.Block.{Reward, SecondDegreeRelation}
  alias Explorer.Chain.Celo.Epoch, as: CeloEpoch
  alias Explorer.Chain.Optimism.TransactionBatch, as: OptimismTransactionBatch
  alias Explorer.Chain.Zilliqa.AggregateQuorumCertificate, as: ZilliqaAggregateQuorumCertificate
  alias Explorer.Chain.Zilliqa.QuorumCertificate, as: ZilliqaQuorumCertificate
  alias Explorer.Chain.Zilliqa.Zrc2.TokenTransfer, as: Zrc2TokenTransfer
  alias Explorer.Chain.ZkSync.BatchBlock, as: ZkSyncBatchBlock

  @chain_type_fields (case @chain_type do
                        :ethereum ->
                          elem(
                            quote do
                              field(:blob_gas_used, :decimal)
                              field(:excess_blob_gas, :decimal)
                              has_many(:beacon_deposits, BeaconDeposit, foreign_key: :block_hash, references: :hash)
                            end,
                            2
                          )

                        :optimism ->
                          elem(
                            quote do
                              has_one(:op_transaction_batch, OptimismTransactionBatch,
                                foreign_key: :l2_block_number,
                                references: :number
                              )

                              has_one(:op_frame_sequence, through: [:op_transaction_batch, :frame_sequence])
                            end,
                            2
                          )

                        :rsk ->
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

                        :zksync ->
                          elem(
                            quote do
                              has_one(:zksync_batch_block, ZkSyncBatchBlock, foreign_key: :hash, references: :hash)
                              has_one(:zksync_batch, through: [:zksync_batch_block, :batch])
                              has_one(:zksync_commit_transaction, through: [:zksync_batch, :commit_transaction])
                              has_one(:zksync_prove_transaction, through: [:zksync_batch, :prove_transaction])
                              has_one(:zksync_execute_transaction, through: [:zksync_batch, :execute_transaction])
                            end,
                            2
                          )

                        :arbitrum ->
                          elem(
                            quote do
                              field(:send_count, :integer)
                              field(:send_root, Hash.Full)
                              field(:l1_block_number, :integer)

                              has_one(:arbitrum_batch_block, ArbitrumBatchBlock,
                                foreign_key: :block_number,
                                references: :number
                              )

                              has_one(:arbitrum_batch, through: [:arbitrum_batch_block, :batch])

                              has_one(:arbitrum_commitment_transaction,
                                through: [:arbitrum_batch, :commitment_transaction]
                              )

                              has_one(:arbitrum_confirmation_transaction,
                                through: [:arbitrum_batch_block, :confirmation_transaction]
                              )
                            end,
                            2
                          )

                        :zilliqa ->
                          elem(
                            quote do
                              field(:zilliqa_view, :integer)

                              has_one(:zilliqa_quorum_certificate, ZilliqaQuorumCertificate,
                                foreign_key: :block_hash,
                                references: :hash
                              )

                              has_one(:zilliqa_aggregate_quorum_certificate, ZilliqaAggregateQuorumCertificate,
                                foreign_key: :block_hash,
                                references: :hash
                              )

                              has_many(:zilliqa_zrc2_token_transfers, Zrc2TokenTransfer,
                                foreign_key: :block_hash,
                                references: :hash
                              )
                            end,
                            2
                          )

                        _ ->
                          []
                      end)

  @chain_identity_fields (case @chain_identity do
                            {:optimism, :celo} ->
                              elem(
                                quote do
                                  has_one(:celo_initiated_epoch, CeloEpoch,
                                    foreign_key: :start_processing_block_hash,
                                    references: :hash
                                  )

                                  has_one(:celo_terminated_epoch, CeloEpoch,
                                    foreign_key: :end_processing_block_hash,
                                    references: :hash
                                  )
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
        field(:aggregated?, :boolean, virtual: true)
        field(:transactions_count, :integer, virtual: true)
        field(:blob_transactions_count, :integer, virtual: true)
        field(:transactions_fees, :decimal, virtual: true)
        field(:burnt_fees, :decimal, virtual: true)
        field(:priority_fees, :decimal, virtual: true)

        timestamps()

        belongs_to(:miner, Address, foreign_key: :miner_hash, references: :hash, type: Hash.Address, null: false)

        has_many(:nephew_relations, SecondDegreeRelation, foreign_key: :uncle_hash, references: :hash)
        has_many(:nephews, through: [:nephew_relations, :nephew], references: :hash)

        belongs_to(:parent, Block, foreign_key: :parent_hash, references: :hash, type: Hash.Full, null: false)

        has_many(:uncle_relations, SecondDegreeRelation, foreign_key: :nephew_hash, references: :hash)
        has_many(:uncles, through: [:uncle_relations, :uncle], references: :hash)

        has_many(:transactions, Transaction, references: :hash)
        has_many(:transaction_forks, Transaction.Fork, foreign_key: :uncle_hash, references: :hash)

        has_many(:internal_transactions, InternalTransaction, foreign_key: :block_number, references: :number)

        has_many(:rewards, Reward, foreign_key: :block_hash, references: :hash)

        has_many(:withdrawals, Withdrawal, foreign_key: :block_hash, references: :hash)

        has_one(:pending_operations, PendingBlockOperation, foreign_key: :block_hash, references: :hash)

        unquote_splicing(@chain_type_fields)
        unquote_splicing(@chain_identity_fields)
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
  use Utils.CompileTimeEnvHelper, chain_type: [:explorer, :chain_type]

  use Utils.RuntimeEnvHelper,
    miner_gets_burnt_fees?: [:explorer, [Explorer.Chain.Transaction, :block_miner_gets_burnt_fees?]]

  alias Explorer.Chain.{
    Block,
    DenormalizationHelper,
    Hash,
    PendingBlockOperation,
    PendingOperationsHelper,
    PendingTransactionOperation,
    Transaction,
    Wei
  }

  alias Explorer.{Chain, Helper, PagingOptions, Repo}
  alias Explorer.Chain.Block.{EmissionReward, Reward, SecondDegreeRelation}
  alias Explorer.Utility.MissingBlockRange

  @optional_attrs ~w(size refetch_needed total_difficulty difficulty base_fee_per_gas)a

  @chain_type_optional_attrs (case @chain_type do
                                :rsk ->
                                  ~w(minimum_gas_price bitcoin_merged_mining_header bitcoin_merged_mining_coinbase_transaction bitcoin_merged_mining_merkle_proof hash_for_merged_mining)a

                                :ethereum ->
                                  ~w(blob_gas_used excess_blob_gas)a

                                :arbitrum ->
                                  ~w(send_count send_root l1_block_number)a

                                :zilliqa ->
                                  ~w(zilliqa_view)a

                                _ ->
                                  ~w()a
                              end)

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
   * `refetch_needed` - `true` if block has missing data and has to be refetched.
   * `transactions` - the `t:Explorer.Chain.Transaction.t/0` in this block.
   * `base_fee_per_gas` - Minimum fee required per unit of gas. Fee adjusts based on network congestion.
  #{case @chain_type do
    :rsk -> """
       * `bitcoin_merged_mining_header` - Bitcoin merged mining header on Rootstock chains.
       * `bitcoin_merged_mining_coinbase_transaction` - Bitcoin merged mining coinbase transaction on Rootstock chains.
       * `bitcoin_merged_mining_merkle_proof` - Bitcoin merged mining merkle proof on Rootstock chains.
       * `hash_for_merged_mining` - Hash for merged mining on Rootstock chains.
       * `minimum_gas_price` - Minimum block gas price on Rootstock chains.
      """
    :ethereum -> """
       * `blob_gas_used` - The total amount of blob gas consumed by the transactions within the block.
       * `excess_blob_gas` - The running total of blob gas consumed in excess of the target, prior to the block.
      """
    _ -> ""
  end}
  """
  Explorer.Chain.Block.Schema.generate()

  def changeset(%__MODULE__{} = block, attrs) do
    block
    |> cast(attrs, @required_attrs ++ @optional_attrs ++ @chain_type_optional_attrs)
    |> validate_required(@required_attrs)
    |> foreign_key_constraint(:parent_hash)
    |> unique_constraint(:hash, name: :blocks_pkey)
  end

  def number_only_changeset(%__MODULE__{} = block, attrs) do
    block
    |> cast(attrs, @required_attrs ++ @optional_attrs ++ @chain_type_optional_attrs)
    |> validate_required([:number])
    |> foreign_key_constraint(:parent_hash)
    |> unique_constraint(:hash, name: :blocks_pkey)
  end

  @doc """
  Returns a query that fetches consensus blocks that do not have validator rewards.
  """
  @spec blocks_without_reward_query() :: Ecto.Query.t()
  def blocks_without_reward_query do
    validator_rewards =
      from(
        r in Reward,
        where: r.address_type == ^"validator"
      )

    from(
      b in subquery(consensus_blocks_query()),
      left_join: r in subquery(validator_rewards),
      on: [block_hash: b.hash],
      where: is_nil(r.block_hash)
    )
  end

  @doc """
    Returns a query that filters blocks where consensus is true.

    ## Returns
    - An `Ecto.Query.t()` that can be used to fetch consensus blocks.
  """
  @spec consensus_blocks_query() :: Ecto.Query.t()
  def consensus_blocks_query do
    from(
      block in __MODULE__,
      where: block.consensus == true
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
        |> Decimal.mult(Helper.number_to_decimal(gas_price))
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
        Helper.number_to_decimal(beacon_blob_transaction.blob_gas_price)
      end
    end)
  end

  @doc """
  Calculates burnt fees for the list of transactions (from a single block)
  """
  @spec burnt_fees(list(), Decimal.t() | nil) :: Decimal.t()
  def burnt_fees(transactions, base_fee_per_gas) do
    if is_nil(base_fee_per_gas) or miner_gets_burnt_fees?() do
      Decimal.new(0)
    else
      transactions
      |> Enum.reduce(Decimal.new(0), fn %{gas_used: gas_used}, acc ->
        gas_used
        |> Decimal.new()
        |> Decimal.add(acc)
      end)
      |> Decimal.mult(Helper.number_to_decimal(base_fee_per_gas))
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
      ) || Wei.zero()

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

  # Gets EIP-1559 config actual for the given block number.
  # If not found, returns EIP_1559_BASE_FEE_MAX_CHANGE_DENOMINATOR and EIP_1559_ELASTICITY_MULTIPLIER env values.
  #
  # ## Parameters
  # - `block_number`: The given block number.
  #
  # ## Returns
  # - `{denominator, multiplier}` tuple.
  @spec get_eip1559_config(non_neg_integer()) :: {non_neg_integer(), non_neg_integer()}
  defp get_eip1559_config(block_number) do
    with true <- Application.get_env(:explorer, :chain_type) == :optimism,
         # credo:disable-for-next-line Credo.Check.Design.AliasUsage
         config = Explorer.Chain.Optimism.EIP1559ConfigUpdate.actual_config_for_block(block_number),
         false <- is_nil(config) do
      {denominator, multiplier, _min_base_fee} = config
      {denominator, multiplier}
    else
      _ ->
        {Application.get_env(:explorer, :base_fee_max_change_denominator),
         Application.get_env(:explorer, :elasticity_multiplier)}
    end
  end

  @doc """
  Calculates the gas target for a given block.

  The gas target represents the percentage by which the actual gas used is above or below the gas target for the block, adjusted by the elasticity multiplier.
  If the `gas_limit` is greater than 0, it calculates the ratio of `gas_used` to `gas_limit` adjusted by this multiplier.

  The multiplier is read from the `EIP_1559_ELASTICITY_MULTIPLIER` env variable or from the `op_eip1559_config_updates` table
  as a dynamic parameter (if OP Holocene upgrade is activated).

  ## Parameters
  - `block`: A map representing block for which the gas target should be calculated.

  ## Returns
  - A float value representing the gas target percentage.
  """
  @spec gas_target(t()) :: float()
  def gas_target(block) do
    if Decimal.compare(block.gas_limit, 0) == :gt do
      {_, elasticity_multiplier} = get_eip1559_config(block.number)

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

  where `elasticity_multiplier` is an env variable `EIP_1559_ELASTICITY_MULTIPLIER` or the dynamic value
  got from the `op_eip1559_config_updates` database table. The `gas_used_delta` is the difference between
  the actual gas used and the target gas. The `base_fee_max_change_denominator` is an env variable
  `EIP_1559_BASE_FEE_MAX_CHANGE_DENOMINATOR` (or the dynamic value got from the `op_eip1559_config_updates`
  table) that limits the maximum change of the base fee from one block to the next.
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
    {base_fee_max_change_denominator, elasticity_multiplier} = get_eip1559_config(block.number)

    gas_target = Decimal.div_int(block.gas_limit, elasticity_multiplier)

    lower_bound = Application.get_env(:explorer, :base_fee_lower_bound)

    base_fee_per_gas_decimal = block.base_fee_per_gas |> Wei.to(:wei)

    base_fee_per_gas_decimal &&
      block.gas_used
      |> Decimal.gt?(gas_target)
      |> if do
        gas_used_delta = Decimal.sub(block.gas_used, gas_target)

        base_fee_per_gas_decimal
        |> get_base_fee_per_gas_delta(gas_used_delta, gas_target, base_fee_max_change_denominator)
        |> Decimal.max(Decimal.new(1))
        |> Decimal.add(base_fee_per_gas_decimal)
      else
        gas_used_delta = Decimal.sub(gas_target, block.gas_used)

        base_fee_per_gas_decimal
        |> get_base_fee_per_gas_delta(gas_used_delta, gas_target, base_fee_max_change_denominator)
        |> Decimal.negate()
        |> Decimal.add(base_fee_per_gas_decimal)
      end
      |> Decimal.max(lower_bound)
  end

  defp get_base_fee_per_gas_delta(base_fee_per_gas_decimal, gas_used_delta, gas_target, base_fee_max_change_denominator) do
    base_fee_per_gas_decimal
    |> Decimal.mult(gas_used_delta)
    |> Decimal.div_int(gas_target)
    |> Decimal.div_int(base_fee_max_change_denominator)
  end

  @spec set_refetch_needed(integer | [integer]) :: :ok
  def set_refetch_needed(block_numbers) when is_list(block_numbers) do
    query =
      from(block in Block,
        where: block.number in ^block_numbers,
        # Enforce Block ShareLocks order (see docs: sharelocks.md)
        order_by: [asc: block.hash],
        lock: "FOR NO KEY UPDATE"
      )

    {_count, updated_numbers} =
      Repo.update_all(
        from(b in Block, join: s in subquery(query), on: b.hash == s.hash, select: b.number),
        set: [refetch_needed: true, updated_at: Timex.now()]
      )

    MissingBlockRange.add_ranges_by_block_numbers(updated_numbers)

    :ok
  end

  def set_refetch_needed(block_number), do: set_refetch_needed([block_number])

  @doc """
  Generates a query to fetch blocks by their hashes.

  ## Parameters

    - `hashes`: A list of block hashes to filter by.

  ## Returns

    - An Ecto query that can be used to retrieve blocks matching the given hashes.
  """
  @spec by_hashes_query([binary()]) :: Ecto.Query.t()
  def by_hashes_query(hashes) do
    __MODULE__
    |> where([block], block.hash in ^hashes)
  end

  @doc """
  Calculates and aggregates transaction-related metrics for a block if not already aggregated.

  This function processes all transactions in a block to compute aggregate
  statistics including transaction counts, fees, burnt fees, and priority fees.
  The aggregation only occurs if the block has not been previously aggregated
  (when `aggregated?` is `nil` or `false`) and contains a list of transactions.

  For each transaction, the function calculates:
  - Total transaction fees (gas_used * gas_price)
  - Burnt fees (gas_used * base_fee_per_gas)
  - Priority fees paid to miners (min of priority fee and effective fee)
  - Blob transaction detection (type 3 transactions)

  ## Parameters
  - `block`: A Block struct containing transactions to be aggregated

  ## Returns
  - Block struct with aggregated transaction metrics and `aggregated?` set to `true`
  - Original block unchanged if already aggregated or transactions is not a list
  """
  @spec aggregate_transactions(t()) :: t()
  def aggregate_transactions(%__MODULE__{transactions: transactions, aggregated?: aggregated?} = block)
      when is_list(transactions) and aggregated? in [nil, false] do
    aggregate_results =
      Enum.reduce(
        transactions,
        %{
          transactions_count: 0,
          blob_transactions_count: 0,
          transactions_fees: Decimal.new(0),
          burnt_fees: Decimal.new(0),
          priority_fees: Decimal.new(0)
        },
        &transaction_aggregator(&1, &2, block.base_fee_per_gas)
      )

    block
    |> Map.merge(aggregate_results)
    |> Map.put(:aggregated?, true)
  end

  def aggregate_transactions(block), do: block

  @doc """
  Checks if block with consensus and not marked to re-fetch block is present in the DB with the given number
  """
  @spec indexed?(non_neg_integer()) :: boolean()
  def indexed?(block_number) do
    query =
      from(
        block in __MODULE__,
        where: block.number == ^block_number,
        where: block.consensus == true,
        where: block.refetch_needed == false
      )

    Repo.exists?(query)
  end

  defp transaction_aggregator(transaction, acc, block_base_fee_per_gas) do
    gas_used = Helper.number_to_decimal(transaction.gas_used)

    transaction_fees =
      if is_nil(transaction.gas_price) do
        acc.transactions_fees
      else
        gas_used
        |> Decimal.new()
        |> Decimal.mult(Helper.number_to_decimal(transaction.gas_price))
        |> Decimal.add(acc.transactions_fees)
      end

    burnt_fees =
      if is_nil(block_base_fee_per_gas) or miner_gets_burnt_fees?() do
        acc.burnt_fees
      else
        transaction.gas_used
        |> Decimal.new()
        |> Decimal.mult(Helper.number_to_decimal(block_base_fee_per_gas))
        |> Decimal.add(acc.burnt_fees)
      end

    priority_fees =
      block_base_fee_per_gas
      |> is_nil()
      |> if do
        acc.priority_fees
      else
        max_fee = Helper.number_to_decimal(transaction.max_fee_per_gas || transaction.gas_price)
        priority_fee = Helper.number_to_decimal(transaction.max_priority_fee_per_gas || transaction.gas_price)

        max_fee
        |> Decimal.eq?(Decimal.new(0))
        |> if do
          Decimal.new(0)
        else
          max_fee
          |> Decimal.sub(Helper.number_to_decimal(block_base_fee_per_gas))
          |> Decimal.min(priority_fee)
          |> Decimal.mult(gas_used)
        end
        |> Decimal.add(acc.priority_fees)
      end

    %{
      transactions_count: acc.transactions_count + 1,
      blob_transactions_count: acc.blob_transactions_count + if(transaction.type == 3, do: 1, else: 0),
      transactions_fees: transaction_fees,
      burnt_fees: burnt_fees,
      priority_fees: priority_fees
    }
  end

  @doc """
  Filters block numbers that do not require refetching.
  ## Parameters
    - `block_numbers`: A list of block numbers to check.
  ## Returns
    - A list of block numbers that do not need to be refetched.
  """
  @spec filter_non_refetch_needed_block_numbers([integer()]) :: [integer()]
  def filter_non_refetch_needed_block_numbers(block_numbers) do
    query =
      from(
        block in __MODULE__,
        where: block.number in ^block_numbers,
        where: block.consensus == true,
        where: block.refetch_needed == false,
        select: block.number
      )

    Repo.all(query)
  end

  @doc """
  Combined block reward from all the fees.
  """
  @spec block_combined_rewards(__MODULE__.t()) :: Wei.t()
  def block_combined_rewards(block) do
    block.rewards
    |> Enum.reduce(
      0,
      fn block_reward, acc ->
        {:ok, decimal} = Wei.dump(block_reward.reward)

        Decimal.add(decimal, acc)
      end
    )
    |> Wei.cast()
    |> case do
      {:ok, value} -> value
      _ -> Wei.zero()
    end
  end

  @doc """
    Fetches the lowest block number available in the database.

    Queries the database for the minimum block number among blocks marked as consensus
    blocks. Returns 0 if no consensus blocks exist or if the query fails.

    ## Returns
    - `non_neg_integer`: The lowest block number from consensus blocks, or 0 if none found
  """
  @spec fetch_min_block_number() :: non_neg_integer
  def fetch_min_block_number do
    query =
      from(block in __MODULE__,
        select: block.number,
        where: block.consensus == true,
        order_by: [asc: block.number],
        limit: 1
      )

    Repo.one(query) || 0
  rescue
    _ ->
      0
  end

  @doc """
    Fetches the highest block number available in the database.

    Queries the database for the maximum block number among blocks marked as consensus
    blocks. Returns 0 if no consensus blocks exist or if the query fails.

    ## Returns
    - `non_neg_integer`: The highest block number from consensus blocks, or 0 if none found
  """
  @spec fetch_max_block_number() :: non_neg_integer
  def fetch_max_block_number do
    query =
      from(block in __MODULE__,
        select: block.number,
        where: block.consensus == true,
        order_by: [desc: block.number],
        limit: 1
      )

    Repo.one(query) || 0
  rescue
    _ ->
      0
  end

  @doc """
  Fetches a block by its hash.
  """
  @spec fetch_block_by_hash(Hash.Full.t()) :: Block.t() | nil
  def fetch_block_by_hash(block_hash) do
    Repo.get(__MODULE__, block_hash)
  end

  @default_page_size 50
  @default_paging_options %PagingOptions{page_size: @default_page_size}

  @doc """
  Finds all Blocks validated by the address with the given hash.

    ## Options
      * `:necessity_by_association` - use to load `t:association/0` as `:required` or `:optional`.  If an association is
          `:required`, and the `t:Explorer.Chain.Block.t/0` has no associated record for that association, then the
          `t:Explorer.Chain.Block.t/0` will not be included in the page `entries`.
      * `:paging_options` - a `t:Explorer.PagingOptions.t/0` used to specify the `:page_size` and
        `:key` (a tuple of the lowest/oldest `{block_number}`) and. Results will be the internal
        transactions older than the `block_number` that are passed.

  Returns all blocks validated by the address given.
  """
  @spec get_blocks_validated_by_address(
          [Chain.paging_options() | Chain.necessity_by_association_option()],
          Hash.Address.t()
        ) :: [Block.t()]
  def get_blocks_validated_by_address(options \\ [], address_hash) when is_list(options) do
    necessity_by_association = Keyword.get(options, :necessity_by_association, %{})
    paging_options = Keyword.get(options, :paging_options, @default_paging_options)

    case paging_options do
      %PagingOptions{key: {0}} ->
        []

      _ ->
        __MODULE__
        |> Chain.join_associations(necessity_by_association)
        |> where(miner_hash: ^address_hash)
        |> Chain.page_blocks(paging_options)
        |> limit(^paging_options.page_size)
        |> order_by(desc: :number)
        |> Chain.select_repo(options).all()
    end
  end

  @doc """
  Calls `reducer` on a stream of `t:Explorer.Chain.Block.t/0` without `t:Explorer.Chain.Block.Reward.t/0`.
  """
  def stream_blocks_without_rewards(initial, reducer, limited? \\ false) when is_function(reducer, 2) do
    blocks_without_reward_query()
    |> Chain.add_fetcher_limit(limited?)
    |> Repo.stream_reduce(initial, reducer)
  end

  @doc """
  Returns a stream of all blocks that are marked as unfetched in `t:Explorer.Chain.Block.SecondDegreeRelation.t/0`.
  For each uncle block a `hash` of nephew block and an `index` of the block in it are returned.

  When a block is fetched, its uncles are transformed into `t:Explorer.Chain.Block.SecondDegreeRelation.t/0` and can be
  returned.  Once the uncle is imported its corresponding `t:Explorer.Chain.Block.SecondDegreeRelation.t/0`
  `uncle_fetched_at` will be set and it won't be returned anymore.
  """
  @spec stream_unfetched_uncles(
          initial :: accumulator,
          reducer :: (entry :: term(), accumulator -> accumulator),
          limited? :: boolean()
        ) :: {:ok, accumulator}
        when accumulator: term()
  def stream_unfetched_uncles(initial, reducer, limited? \\ false) when is_function(reducer, 2) do
    query =
      from(bsdr in SecondDegreeRelation,
        where: is_nil(bsdr.uncle_fetched_at) and not is_nil(bsdr.index),
        select: [:nephew_hash, :index]
      )

    query
    |> Chain.add_fetcher_limit(limited?)
    |> Repo.stream_reduce(initial, reducer)
  end

  @doc """
  Map `block_number`s to their `t:Explorer.Chain.Block.t/0` `hash` `t:Explorer.Chain.Hash.Full.t/0`.

  Does not include non-consensus blocks.

      iex> block = insert(:block, consensus: false)
      iex> Explorer.Chain.Block.block_hash_by_number([block.number])
      %{}

  """
  @spec block_hash_by_number([Block.block_number()]) :: %{Block.block_number() => Hash.Full.t()}
  def block_hash_by_number(block_numbers) when is_list(block_numbers) do
    query =
      from(block in __MODULE__,
        where: block.consensus == true and block.number in ^block_numbers,
        select: {block.number, block.hash}
      )

    query
    |> Repo.all()
    |> Enum.into(%{})
  end

  @doc """
  Removes pending operations associated with non-consensus blocks.
  """
  @spec remove_nonconsensus_blocks_from_pending_ops([Hash.Full.t()]) :: :ok
  def remove_nonconsensus_blocks_from_pending_ops(block_hashes) do
    query =
      case PendingOperationsHelper.pending_operations_type() do
        "blocks" ->
          PendingOperationsHelper.block_hash_in_query(block_hashes)

        "transactions" ->
          from(
            pto in PendingTransactionOperation,
            join: t in assoc(pto, :transaction),
            where: t.block_hash in ^block_hashes
          )
      end

    {_, _} = Repo.delete_all(query)

    :ok
  end

  @doc """
  Removes pending operations associated with all non-consensus blocks.
  """
  @spec remove_nonconsensus_blocks_from_pending_ops() :: :ok
  def remove_nonconsensus_blocks_from_pending_ops do
    query =
      case PendingOperationsHelper.pending_operations_type() do
        "blocks" ->
          from(
            pbo in PendingBlockOperation,
            inner_join: block in Block,
            on: block.hash == pbo.block_hash,
            where: block.consensus == false
          )

        "transactions" ->
          from(
            pto in PendingTransactionOperation,
            join: t in assoc(pto, :transaction),
            where: t.block_consensus == false
          )
      end

    {_, _} = Repo.delete_all(query)

    :ok
  end

  @spec nonconsensus_block_by_number(Block.block_number(), [Chain.api?()]) :: {:ok, Block.t()} | {:error, :not_found}
  def nonconsensus_block_by_number(number, options) do
    __MODULE__
    |> where(consensus: false, number: ^number)
    |> Chain.select_repo(options).one()
    |> case do
      nil -> {:error, :not_found}
      block -> {:ok, block}
    end
  end

  @doc """
  The `t:Explorer.Chain.Wei.t/0` paid to the miners of the `t:Explorer.Chain.Block.t/0`s with `hash`
  `Explorer.Chain.Hash.Full.t/0` by the signers of the transactions in those blocks to cover the gas fee
  (`gas_used * gas_price`).
  """
  @spec gas_payment_by_block_hash([Hash.Full.t()]) :: %{Hash.Full.t() => Wei.t()}
  def gas_payment_by_block_hash(block_hashes) when is_list(block_hashes) do
    query =
      if DenormalizationHelper.transactions_denormalization_finished?() do
        from(
          transaction in Transaction,
          where: transaction.block_hash in ^block_hashes and transaction.block_consensus == true,
          group_by: transaction.block_hash,
          select: {transaction.block_hash, %Wei{value: coalesce(sum(transaction.gas_used * transaction.gas_price), 0)}}
        )
      else
        from(
          block in __MODULE__,
          left_join: transaction in assoc(block, :transactions),
          where: block.hash in ^block_hashes and block.consensus == true,
          group_by: block.hash,
          select: {block.hash, %Wei{value: coalesce(sum(transaction.gas_used * transaction.gas_price), 0)}}
        )
      end

    initial_gas_payments =
      block_hashes
      |> Enum.map(&{&1, Wei.zero()})
      |> Enum.into(%{})

    existing_data =
      query
      |> Repo.all()
      |> Enum.into(%{})

    Map.merge(initial_gas_payments, existing_data)
  end

  @doc """
  The `timestamp` of the `t:Explorer.Chain.Block.t/0`s with `hash` `Explorer.Chain.Hash.Full.t/0`.
  """
  @spec timestamp_by_block_hash([Hash.Full.t()]) :: %{Hash.Full.t() => non_neg_integer()}
  def timestamp_by_block_hash(block_hashes) when is_list(block_hashes) do
    query =
      from(
        block in __MODULE__,
        where: block.hash in ^block_hashes and block.consensus == true,
        group_by: block.hash,
        select: {block.hash, block.timestamp}
      )

    query
    |> Repo.all()
    |> Enum.into(%{})
  end

  @doc """
  Fetches the second block in the database ordered by number in ascending order.
  """
  @spec fetch_second_block_in_database() :: {:ok, __MODULE__.t()} | {:error, :not_found}
  def fetch_second_block_in_database do
    query =
      from(block in __MODULE__,
        where: block.consensus == true,
        order_by: [asc: block.number],
        offset: 1,
        limit: 1,
        select: block
      )

    case Repo.one(query) do
      nil -> {:error, :not_found}
      block -> {:ok, block}
    end
  end
end
