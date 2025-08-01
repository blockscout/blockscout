defmodule Explorer.Chain.Import.Runner.Blocks do
  @moduledoc """
  Bulk imports `t:Explorer.Chain.Block.t/0`.
  """

  require Ecto.Query

  import Ecto.Query, only: [dynamic: 1, dynamic: 2, from: 2, where: 3, subquery: 1]
  import Explorer.Chain.Import.Runner.Helper, only: [chain_type_dependent_import: 3]

  alias Ecto.{Changeset, Multi, Repo}

  alias EthereumJSONRPC.Utility.RangesHelper

  alias Explorer.Chain.{
    Address,
    Block,
    BlockNumberHelper,
    DenormalizationHelper,
    Import,
    PendingBlockOperation,
    PendingOperationsHelper,
    Token,
    Token.Instance,
    TokenTransfer,
    Transaction
  }

  alias Explorer.Chain.Block.Reward
  alias Explorer.Chain.Import.Runner
  alias Explorer.Chain.Import.Runner.Address.CurrentTokenBalances
  alias Explorer.Chain.Import.Runner.{Addresses, TokenInstances, Tokens}
  alias Explorer.Prometheus.Instrumenter
  alias Explorer.Repo, as: ExplorerRepo
  alias Explorer.Utility.MissingRangesManipulator

  alias Explorer.Chain.Celo.ElectionReward, as: CeloElectionReward
  alias Explorer.Chain.Celo.Epoch, as: CeloEpoch
  alias Explorer.Chain.Celo.EpochReward, as: CeloEpochReward

  @behaviour Runner

  # milliseconds
  @timeout 60_000

  @type imported :: [Block.t()]

  @impl Runner
  def ecto_schema_module, do: Block

  @impl Runner
  def option_key, do: :blocks

  @impl Runner
  def imported_table_row do
    %{
      value_type: "[#{ecto_schema_module()}.t()]",
      value_description: "List of `t:#{ecto_schema_module()}.t/0`s"
    }
  end

  @impl Runner
  def run(multi, changes_list, %{timestamps: timestamps} = options) do
    insert_options =
      options
      |> Map.get(option_key(), %{})
      |> Map.take(~w(on_conflict timeout)a)
      |> Map.put_new(:timeout, @timeout)
      |> Map.put(:timestamps, timestamps)

    hashes = Enum.map(changes_list, & &1.hash)

    # Enforce ShareLocks tables order (see docs: sharelocks.md)
    run_func = fn repo ->
      {:ok, nonconsensus_items} = process_blocks_consensus(changes_list, repo, insert_options)

      {:ok,
       RangesHelper.filter_by_height_range(nonconsensus_items, fn {number, _hash} ->
         RangesHelper.traceable_block_number?(number)
       end)}
    end

    multi
    |> Multi.run(:lose_consensus, fn repo, _ ->
      Instrumenter.block_import_stage_runner(
        fn -> run_func.(repo) end,
        :address_referencing,
        :blocks,
        :lose_consensus
      )
    end)
    |> Multi.run(:blocks, fn repo, _ ->
      Instrumenter.block_import_stage_runner(
        fn ->
          # Note, needs to be executed after `lose_consensus` for lock acquisition
          insert(repo, changes_list, insert_options)
        end,
        :address_referencing,
        :blocks,
        :blocks
      )
    end)
    |> Multi.run(:new_pending_block_operations, fn repo, %{blocks: blocks} ->
      Instrumenter.block_import_stage_runner(
        fn ->
          new_pending_block_operations(repo, blocks, insert_options)
        end,
        :address_referencing,
        :blocks,
        :new_pending_block_operations
      )
    end)
    |> Multi.run(:uncle_fetched_block_second_degree_relations, fn repo, _ ->
      Instrumenter.block_import_stage_runner(
        fn ->
          update_block_second_degree_relations(repo, hashes, %{
            timeout:
              options[Runner.Block.SecondDegreeRelations.option_key()][:timeout] ||
                Runner.Block.SecondDegreeRelations.timeout(),
            timestamps: timestamps
          })
        end,
        :address_referencing,
        :blocks,
        :uncle_fetched_block_second_degree_relations
      )
    end)
    |> Multi.run(:delete_rewards, fn repo, _ ->
      Instrumenter.block_import_stage_runner(
        fn -> delete_rewards(repo, changes_list, insert_options) end,
        :address_referencing,
        :blocks,
        :delete_rewards
      )
    end)
    |> Multi.run(:fork_transactions, fn repo, _ ->
      Instrumenter.block_import_stage_runner(
        fn ->
          fork_transactions(%{
            repo: repo,
            timeout: options[Runner.Transactions.option_key()][:timeout] || Runner.Transactions.timeout(),
            timestamps: timestamps,
            blocks_changes: changes_list
          })
        end,
        :address_referencing,
        :blocks,
        :fork_transactions
      )
    end)
    |> Multi.run(:derive_transaction_forks, fn repo, %{fork_transactions: transactions} ->
      Instrumenter.block_import_stage_runner(
        fn ->
          derive_transaction_forks(%{
            repo: repo,
            timeout: options[Runner.Transaction.Forks.option_key()][:timeout] || Runner.Transaction.Forks.timeout(),
            timestamps: timestamps,
            transactions: transactions
          })
        end,
        :address_referencing,
        :blocks,
        :derive_transaction_forks
      )
    end)
    |> Multi.run(:delete_address_coin_balances, fn repo, %{lose_consensus: non_consensus_blocks} ->
      Instrumenter.block_import_stage_runner(
        fn -> delete_address_coin_balances(repo, non_consensus_blocks, insert_options) end,
        :address_referencing,
        :blocks,
        :delete_address_coin_balances
      )
    end)
    |> Multi.run(:derive_address_fetched_coin_balances, fn repo,
                                                           %{delete_address_coin_balances: delete_address_coin_balances} ->
      Instrumenter.block_import_stage_runner(
        fn -> derive_address_fetched_coin_balances(repo, delete_address_coin_balances, insert_options) end,
        :address_referencing,
        :blocks,
        :derive_address_fetched_coin_balances
      )
    end)
    |> Multi.run(:delete_address_token_balances, fn repo, %{lose_consensus: non_consensus_blocks} ->
      Instrumenter.block_import_stage_runner(
        fn -> delete_address_token_balances(repo, non_consensus_blocks, insert_options) end,
        :address_referencing,
        :blocks,
        :delete_address_token_balances
      )
    end)
    |> Multi.run(:delete_address_current_token_balances, fn repo, %{lose_consensus: non_consensus_blocks} ->
      Instrumenter.block_import_stage_runner(
        fn -> delete_address_current_token_balances(repo, non_consensus_blocks, insert_options) end,
        :address_referencing,
        :blocks,
        :delete_address_current_token_balances
      )
    end)
    |> Multi.run(:derive_address_current_token_balances, fn repo,
                                                            %{
                                                              delete_address_current_token_balances:
                                                                deleted_address_current_token_balances
                                                            } ->
      Instrumenter.block_import_stage_runner(
        fn -> derive_address_current_token_balances(repo, deleted_address_current_token_balances, insert_options) end,
        :address_referencing,
        :blocks,
        :derive_address_current_token_balances
      )
    end)
    |> Multi.run(:update_token_instances_owner, fn repo, %{derive_transaction_forks: transactions} ->
      Instrumenter.block_import_stage_runner(
        fn -> update_token_instances_owner(repo, transactions, insert_options) end,
        :address_referencing,
        :blocks,
        :update_token_instances_owner
      )
    end)
    |> Multi.run(:blocks_update_token_holder_counts, fn repo,
                                                        %{
                                                          delete_address_current_token_balances: deleted,
                                                          derive_address_current_token_balances: inserted
                                                        } ->
      Instrumenter.block_import_stage_runner(
        fn ->
          deltas = CurrentTokenBalances.token_holder_count_deltas(%{deleted: deleted, inserted: inserted})
          Tokens.update_holder_counts_with_deltas(repo, deltas, insert_options)
        end,
        :address_referencing,
        :blocks,
        :blocks_update_token_holder_counts
      )
    end)
    |> chain_type_dependent_import(
      :celo,
      &Multi.run(
        &1,
        :celo_delete_epoch_rewards,
        fn repo, %{lose_consensus: non_consensus_blocks} ->
          Instrumenter.block_import_stage_runner(
            fn -> celo_delete_epoch_rewards(repo, non_consensus_blocks, insert_options) end,
            :address_referencing,
            :blocks,
            :celo_delete_epoch_rewards
          )
        end
      )
    )
  end

  @impl Runner
  def timeout, do: @timeout

  defp fork_transactions(%{
         repo: repo,
         timeout: timeout,
         timestamps: %{updated_at: updated_at},
         blocks_changes: blocks_changes
       }) do
    query =
      from(
        transaction in where_forked(blocks_changes),
        select: transaction,
        # Enforce Transaction ShareLocks order (see docs: sharelocks.md)
        order_by: [asc: :hash],
        lock: "FOR NO KEY UPDATE"
      )

    update_query =
      from(
        t in Transaction,
        join: s in subquery(query),
        on: t.hash == s.hash,
        update: [
          set: [
            block_hash: nil,
            block_number: nil,
            gas_used: nil,
            cumulative_gas_used: nil,
            index: nil,
            status: nil,
            error: nil,
            max_priority_fee_per_gas: nil,
            max_fee_per_gas: nil,
            type: nil,
            updated_at: ^updated_at
          ]
        ],
        select: s
      )

    {_num, transactions} = repo.update_all(update_query, [], timeout: timeout)

    {:ok, transactions}
  rescue
    postgrex_error in Postgrex.Error ->
      {:error, %{exception: postgrex_error}}
  end

  defp derive_transaction_forks(%{
         repo: repo,
         timeout: timeout,
         timestamps: %{inserted_at: inserted_at, updated_at: updated_at},
         transactions: transactions
       }) do
    transaction_forks =
      transactions
      |> Enum.map(fn transaction ->
        %{
          uncle_hash: transaction.block_hash,
          index: transaction.index,
          hash: transaction.hash,
          inserted_at: inserted_at,
          updated_at: updated_at
        }
      end)
      # Enforce Fork ShareLocks order (see docs: sharelocks.md)
      |> Enum.sort_by(&{&1.uncle_hash, &1.index})

    {_total, forked_transaction} =
      repo.insert_all(
        Transaction.Fork,
        transaction_forks,
        conflict_target: [:uncle_hash, :index],
        on_conflict:
          from(
            transaction_fork in Transaction.Fork,
            update: [set: [hash: fragment("EXCLUDED.hash")]],
            where: fragment("EXCLUDED.hash <> ?", transaction_fork.hash)
          ),
        returning: [:hash],
        timeout: timeout
      )

    {:ok, Enum.map(forked_transaction, & &1.hash)}
  end

  @spec insert(Repo.t(), [map()], %{
          optional(:on_conflict) => Runner.on_conflict(),
          required(:timeout) => timeout,
          required(:timestamps) => Import.timestamps()
        }) :: {:ok, [Block.t()]} | {:error, [Changeset.t()]}
  defp insert(repo, changes_list, %{timeout: timeout, timestamps: timestamps} = options) when is_list(changes_list) do
    on_conflict = Map.get_lazy(options, :on_conflict, &default_on_conflict/0)

    # Enforce Block ShareLocks order (see docs: sharelocks.md)
    ordered_changes_list =
      changes_list
      |> Enum.sort_by(& &1.hash)
      |> Enum.dedup_by(& &1.hash)

    Import.insert_changes_list(
      repo,
      ordered_changes_list,
      conflict_target: :hash,
      on_conflict: on_conflict,
      for: Block,
      returning: true,
      timeout: timeout,
      timestamps: timestamps
    )
  end

  defp default_on_conflict do
    chain_type = Application.get_env(:explorer, :chain_type)

    base_fields = [
      consensus: dynamic(fragment("EXCLUDED.consensus")),
      difficulty: dynamic(fragment("EXCLUDED.difficulty")),
      gas_limit: dynamic(fragment("EXCLUDED.gas_limit")),
      gas_used: dynamic(fragment("EXCLUDED.gas_used")),
      miner_hash: dynamic(fragment("EXCLUDED.miner_hash")),
      nonce: dynamic(fragment("EXCLUDED.nonce")),
      number: dynamic(fragment("EXCLUDED.number")),
      parent_hash: dynamic(fragment("EXCLUDED.parent_hash")),
      size: dynamic(fragment("EXCLUDED.size")),
      timestamp: dynamic(fragment("EXCLUDED.timestamp")),
      total_difficulty: dynamic(fragment("EXCLUDED.total_difficulty")),
      refetch_needed: dynamic(fragment("EXCLUDED.refetch_needed")),
      base_fee_per_gas: dynamic(fragment("EXCLUDED.base_fee_per_gas")),
      is_empty: dynamic(fragment("EXCLUDED.is_empty")),
      # Don't update `hash` as it is used for the conflict target
      inserted_at: dynamic([block], fragment("LEAST(?, EXCLUDED.inserted_at)", block.inserted_at)),
      updated_at: dynamic([block], fragment("GREATEST(?, EXCLUDED.updated_at)", block.updated_at))
    ]

    base_condition =
      dynamic(
        [block],
        fragment(
          "(EXCLUDED.consensus, EXCLUDED.difficulty, EXCLUDED.gas_limit, EXCLUDED.gas_used, EXCLUDED.miner_hash, EXCLUDED.nonce, EXCLUDED.number, EXCLUDED.parent_hash, EXCLUDED.size, EXCLUDED.timestamp, EXCLUDED.total_difficulty, EXCLUDED.refetch_needed, EXCLUDED.base_fee_per_gas, EXCLUDED.is_empty) IS DISTINCT FROM (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
          block.consensus,
          block.difficulty,
          block.gas_limit,
          block.gas_used,
          block.miner_hash,
          block.nonce,
          block.number,
          block.parent_hash,
          block.size,
          block.timestamp,
          block.total_difficulty,
          block.refetch_needed,
          block.base_fee_per_gas,
          block.is_empty
        )
      )

    case on_conflict_chain_type_extension(chain_type) do
      {chain_type_fields, chain_type_condition} ->
        base_with_chain_type_fields = Keyword.merge(base_fields, chain_type_fields)
        base_with_chain_type_condition = dynamic(^base_condition or ^chain_type_condition)

        from(
          block in Block,
          update: ^[set: base_with_chain_type_fields],
          where: ^base_with_chain_type_condition
        )

      _ ->
        from(
          block in Block,
          update: ^[set: base_fields],
          where: ^base_condition
        )
    end
  end

  defp on_conflict_chain_type_extension(:ethereum) do
    {
      [
        blob_gas_used: dynamic(fragment("EXCLUDED.blob_gas_used")),
        excess_blob_gas: dynamic(fragment("EXCLUDED.excess_blob_gas"))
      ],
      dynamic(
        [block],
        fragment(
          "(EXCLUDED.blob_gas_used, EXCLUDED.excess_blob_gas) IS DISTINCT FROM (?, ?)",
          block.blob_gas_used,
          block.excess_blob_gas
        )
      )
    }
  end

  defp on_conflict_chain_type_extension(:rsk) do
    {
      [
        bitcoin_merged_mining_header: dynamic(fragment("EXCLUDED.bitcoin_merged_mining_header")),
        bitcoin_merged_mining_coinbase_transaction:
          dynamic(fragment("EXCLUDED.bitcoin_merged_mining_coinbase_transaction")),
        bitcoin_merged_mining_merkle_proof: dynamic(fragment("EXCLUDED.bitcoin_merged_mining_merkle_proof")),
        hash_for_merged_mining: dynamic(fragment("EXCLUDED.hash_for_merged_mining")),
        minimum_gas_price: dynamic(fragment("EXCLUDED.minimum_gas_price"))
      ],
      dynamic(
        [block],
        fragment(
          "(EXCLUDED.bitcoin_merged_mining_header, EXCLUDED.bitcoin_merged_mining_coinbase_transaction, EXCLUDED.bitcoin_merged_mining_merkle_proof, EXCLUDED.hash_for_merged_mining, EXCLUDED.minimum_gas_price) IS DISTINCT FROM (?, ?, ?, ?, ?)",
          block.bitcoin_merged_mining_header,
          block.bitcoin_merged_mining_coinbase_transaction,
          block.bitcoin_merged_mining_merkle_proof,
          block.hash_for_merged_mining,
          block.minimum_gas_price
        )
      )
    }
  end

  defp on_conflict_chain_type_extension(:arbitrum) do
    {
      [
        send_count: dynamic(fragment("EXCLUDED.send_count")),
        send_root: dynamic(fragment("EXCLUDED.send_root")),
        l1_block_number: dynamic(fragment("EXCLUDED.l1_block_number"))
      ],
      dynamic(
        [block],
        fragment(
          "(EXCLUDED.send_count, EXCLUDED.send_root, EXCLUDED.l1_block_number) IS DISTINCT FROM (?, ?, ?)",
          block.send_count,
          block.send_root,
          block.l1_block_number
        )
      )
    }
  end

  defp on_conflict_chain_type_extension(:zilliqa) do
    {
      [
        zilliqa_view: dynamic(fragment("EXCLUDED.zilliqa_view"))
      ],
      dynamic(
        [block],
        fragment(
          "EXCLUDED.zilliqa_view IS DISTINCT FROM ?",
          block.zilliqa_view
        )
      )
    }
  end

  defp on_conflict_chain_type_extension(_), do: nil

  defp consensus_block_numbers(blocks_changes) when is_list(blocks_changes) do
    blocks_changes
    |> Enum.filter(& &1.consensus)
    |> Enum.map(& &1.number)
  end

  defp lose_consensus(repo, changes_list, %{
         timeout: timeout,
         timestamps: %{updated_at: updated_at}
       }) do
    hashes = Enum.map(changes_list, & &1.hash)
    consensus_block_numbers = consensus_block_numbers(changes_list)

    acquire_query =
      from(
        block in where_invalid_neighbor(changes_list),
        or_where: block.number in ^consensus_block_numbers,
        # we also need to acquire blocks that will be upserted here, for ordering
        or_where: block.hash in ^hashes,
        select: %{hash: block.hash, number: block.number},
        # Enforce Block ShareLocks order (see docs: sharelocks.md)
        order_by: [asc: block.hash],
        lock: "FOR NO KEY UPDATE"
      )

    {_, removed_consensus_blocks} =
      repo.update_all(
        from(
          block in Block,
          join: s in subquery(acquire_query),
          on: block.hash == s.hash,
          # we don't want to remove consensus from blocks that will be upserted
          where: block.hash not in ^hashes,
          select: {block.number, block.hash}
        ),
        [set: [consensus: false, updated_at: updated_at]],
        timeout: timeout
      )

    repo.update_all(
      from(
        transaction in Transaction,
        join: s in subquery(acquire_query),
        on: transaction.block_hash == s.hash,
        # we don't want to remove consensus from blocks that will be upserted
        where: transaction.block_hash not in ^hashes
      ),
      [set: [block_consensus: false, updated_at: updated_at]],
      timeout: timeout
    )

    repo.update_all(
      from(
        token_transfer in TokenTransfer,
        join: s in subquery(acquire_query),
        on: token_transfer.block_number == s.number,
        # we don't want to remove consensus from blocks that will be upserted
        where: token_transfer.block_hash not in ^hashes
      ),
      [set: [block_consensus: false, updated_at: updated_at]],
      timeout: timeout
    )

    removed_consensus_blocks
    |> Enum.map(fn {number, _hash} -> number end)
    |> Enum.reject(&Enum.member?(consensus_block_numbers, &1))
    |> MissingRangesManipulator.add_ranges_by_block_numbers()

    {:ok, removed_consensus_blocks}
  rescue
    postgrex_error in Postgrex.Error ->
      {:error, %{exception: postgrex_error}}
  end

  @doc """
    Processes consensus for blocks that failed to import completely.

    This function handles the consistency updates needed when a block import fails,
    ensuring that the chain's consensus state remains valid.

    ## Parameters
    - `blocks_changes`: List of block changes to process

    ## Returns
    - `{:ok, removed_consensus_blocks}`: List of tuples {number, hash} for blocks that lost consensus
    - `{:error, reason}`: The error encountered during processing
  """
  @spec process_blocks_consensus([map()], module(), map() | nil) ::
          {:ok, [{non_neg_integer(), binary()}]} | {:error, map()}
  def process_blocks_consensus(blocks_changes, repo \\ ExplorerRepo, insert_options \\ nil) do
    opts =
      insert_options ||
        %{
          timeout: @timeout,
          timestamps: %{updated_at: DateTime.utc_now()}
        }

    lose_consensus(repo, blocks_changes, opts)
  end

  defp new_pending_block_operations(repo, inserted_blocks, %{timeout: timeout, timestamps: timestamps}) do
    case PendingOperationsHelper.pending_operations_type() do
      "blocks" ->
        sorted_pending_ops =
          inserted_blocks
          |> RangesHelper.filter_by_height_range(&RangesHelper.traceable_block_number?(&1.number))
          |> Enum.filter(& &1.consensus)
          |> Enum.map(&%{block_hash: &1.hash, block_number: &1.number})
          |> Enum.sort()

        Import.insert_changes_list(
          repo,
          sorted_pending_ops,
          conflict_target: :block_hash,
          on_conflict: :nothing,
          for: PendingBlockOperation,
          returning: true,
          timeout: timeout,
          timestamps: timestamps
        )

      _other_type ->
        {:ok, []}
    end
  end

  defp delete_address_coin_balances(_repo, [], _options), do: {:ok, []}

  defp delete_address_coin_balances(repo, non_consensus_blocks, %{timeout: timeout}) do
    non_consensus_block_numbers = Enum.map(non_consensus_blocks, fn {number, _hash} -> number end)

    ordered_query =
      from(cb in Address.CoinBalance,
        where: cb.block_number in ^non_consensus_block_numbers,
        select: map(cb, [:address_hash, :block_number]),
        # Enforce TokenBalance ShareLocks order (see docs: sharelocks.md)
        order_by: [cb.address_hash, cb.block_number],
        lock: "FOR UPDATE"
      )

    query =
      from(cb in Address.CoinBalance,
        select: {cb.address_hash, cb.block_number},
        inner_join: ordered_address_coin_balance in subquery(ordered_query),
        on:
          ordered_address_coin_balance.address_hash == cb.address_hash and
            ordered_address_coin_balance.block_number == cb.block_number
      )

    try do
      {_count, deleted_coin_balances} = repo.delete_all(query, timeout: timeout)

      {:ok, deleted_coin_balances}
    rescue
      postgrex_error in Postgrex.Error ->
        {:error, %{exception: postgrex_error, block_numbers: non_consensus_block_numbers}}
    end
  end

  defp derive_address_fetched_coin_balances(_repo, [], _options), do: {:ok, []}

  defp derive_address_fetched_coin_balances(repo, deleted_coin_balances, options) do
    {deleted_balances_address_hashes, deleted_balances_block_numbers} = Enum.unzip(deleted_coin_balances)

    filtered_address_hashes_query =
      from(a in Address,
        where:
          a.hash in ^deleted_balances_address_hashes and
            a.fetched_coin_balance_block_number in ^deleted_balances_block_numbers,
        select: a.hash
      )

    filtered_address_hashes = repo.all(filtered_address_hashes_query)

    last_balances_query =
      from(cb in Address.CoinBalance,
        where: cb.address_hash in ^filtered_address_hashes,
        where: not is_nil(cb.value),
        distinct: cb.address_hash,
        order_by: [asc: cb.address_hash, desc: cb.block_number],
        select: %{
          hash: cb.address_hash,
          fetched_coin_balance: cb.value,
          fetched_coin_balance_block_number: cb.block_number
        }
      )

    addresses_params =
      last_balances_query
      |> repo.all()
      |> Enum.sort_by(& &1.hash)

    addresses_options =
      Map.put(options, :on_conflict, {:replace, [:fetched_coin_balance, :fetched_coin_balance_block_number]})

    Addresses.insert(repo, addresses_params, addresses_options)
  end

  defp delete_address_token_balances(_, [], _), do: {:ok, []}

  defp delete_address_token_balances(repo, non_consensus_blocks, %{timeout: timeout}) do
    non_consensus_block_numbers = Enum.map(non_consensus_blocks, fn {number, _hash} -> number end)

    ordered_query =
      from(tb in Address.TokenBalance,
        where: tb.block_number in ^non_consensus_block_numbers,
        select: map(tb, [:address_hash, :token_contract_address_hash, :token_id, :block_number]),
        # Enforce TokenBalance ShareLocks order (see docs: sharelocks.md)
        order_by: [
          tb.token_contract_address_hash,
          tb.token_id,
          tb.address_hash,
          tb.block_number
        ],
        lock: "FOR UPDATE"
      )

    query =
      from(tb in Address.TokenBalance,
        select: map(tb, [:address_hash, :token_contract_address_hash, :block_number]),
        inner_join: ordered_address_token_balance in subquery(ordered_query),
        on:
          ordered_address_token_balance.address_hash == tb.address_hash and
            ordered_address_token_balance.token_contract_address_hash ==
              tb.token_contract_address_hash and
            ((is_nil(ordered_address_token_balance.token_id) and is_nil(tb.token_id)) or
               (ordered_address_token_balance.token_id == tb.token_id and
                  not is_nil(ordered_address_token_balance.token_id) and not is_nil(tb.token_id))) and
            ordered_address_token_balance.block_number == tb.block_number
      )

    try do
      {_count, deleted_address_token_balances} = repo.delete_all(query, timeout: timeout)

      {:ok, deleted_address_token_balances}
    rescue
      postgrex_error in Postgrex.Error ->
        {:error, %{exception: postgrex_error, block_numbers: non_consensus_block_numbers}}
    end
  end

  defp delete_address_current_token_balances(_, [], _), do: {:ok, []}

  defp delete_address_current_token_balances(repo, non_consensus_blocks, %{timeout: timeout}) do
    non_consensus_block_numbers = Enum.map(non_consensus_blocks, fn {number, _hash} -> number end)

    ordered_query =
      from(ctb in Address.CurrentTokenBalance,
        where: ctb.block_number in ^non_consensus_block_numbers,
        select: map(ctb, [:address_hash, :token_contract_address_hash, :token_id]),
        # Enforce CurrentTokenBalance ShareLocks order (see docs: sharelocks.md)
        order_by: [
          ctb.token_contract_address_hash,
          ctb.token_id,
          ctb.address_hash
        ],
        lock: "FOR UPDATE"
      )

    query =
      from(ctb in Address.CurrentTokenBalance,
        select:
          map(ctb, [
            :address_hash,
            :token_contract_address_hash,
            :token_id,
            # Used to determine if `address_hash` was a holder of `token_contract_address_hash` before

            # `address_current_token_balance` is deleted in `update_tokens_holder_count`.
            :value
          ]),
        inner_join: ordered_address_current_token_balance in subquery(ordered_query),
        on:
          ordered_address_current_token_balance.address_hash == ctb.address_hash and
            ordered_address_current_token_balance.token_contract_address_hash == ctb.token_contract_address_hash and
            ((is_nil(ordered_address_current_token_balance.token_id) and is_nil(ctb.token_id)) or
               (ordered_address_current_token_balance.token_id == ctb.token_id and
                  not is_nil(ordered_address_current_token_balance.token_id) and not is_nil(ctb.token_id)))
      )

    try do
      {_count, deleted_address_current_token_balances} = repo.delete_all(query, timeout: timeout)

      {:ok, deleted_address_current_token_balances}
    rescue
      postgrex_error in Postgrex.Error ->
        {:error, %{exception: postgrex_error, block_numbers: non_consensus_block_numbers}}
    end
  end

  defp derive_address_current_token_balances(_, [], _), do: {:ok, []}

  defp derive_address_current_token_balances(
         repo,
         deleted_address_current_token_balances,
         %{timeout: timeout} = options
       )
       when is_list(deleted_address_current_token_balances) do
    final_query = derive_address_current_token_balances_grouped_query(deleted_address_current_token_balances)

    new_current_token_balance_query =
      from(new_current_token_balance in subquery(final_query),
        inner_join: tb in Address.TokenBalance,
        on:
          tb.address_hash == new_current_token_balance.address_hash and
            tb.token_contract_address_hash == new_current_token_balance.token_contract_address_hash and
            ((is_nil(tb.token_id) and is_nil(new_current_token_balance.token_id)) or
               (tb.token_id == new_current_token_balance.token_id and
                  not is_nil(tb.token_id) and not is_nil(new_current_token_balance.token_id))) and
            tb.block_number == new_current_token_balance.block_number,
        select: %{
          address_hash: new_current_token_balance.address_hash,
          token_contract_address_hash: new_current_token_balance.token_contract_address_hash,
          token_id: new_current_token_balance.token_id,
          token_type: tb.token_type,
          block_number: new_current_token_balance.block_number,
          value: tb.value,
          value_fetched_at: tb.value_fetched_at,
          inserted_at: over(min(tb.inserted_at), :w),
          updated_at: over(max(tb.updated_at), :w)
        },
        windows: [
          w: [partition_by: [tb.address_hash, tb.token_contract_address_hash, tb.token_id]]
        ]
      )

    current_token_balance =
      new_current_token_balance_query
      |> repo.all()

    timestamps = Import.timestamps()

    result =
      CurrentTokenBalances.insert_changes_list_with_and_without_token_id(
        current_token_balance,
        repo,
        timestamps,
        timeout,
        options
      )

    derived_address_current_token_balances =
      Enum.map(result, &Map.take(&1, [:address_hash, :token_contract_address_hash, :token_id, :block_number, :value]))

    {:ok, derived_address_current_token_balances}
  end

  defp update_token_instances_owner(_, [], _), do: {:ok, []}

  defp update_token_instances_owner(repo, forked_transaction_hashes, options) do
    forked_transaction_hashes
    |> forked_token_transfers_query()
    |> repo.all()
    |> process_forked_token_transfers(repo, options)
  end

  defp process_forked_token_transfers([], _, _), do: {:ok, []}

  defp process_forked_token_transfers(token_transfers, repo, options) do
    changes_initial =
      Enum.reduce(token_transfers, %{}, fn tt, acc ->
        Map.put_new(acc, {tt.token_contract_address_hash, tt.token_id}, %{
          token_contract_address_hash: tt.token_contract_address_hash,
          token_id: tt.token_id,
          owner_address_hash: tt.from,
          owner_updated_at_block: -1,
          owner_updated_at_log_index: -1
        })
      end)

    non_consensus_block_numbers = token_transfers |> Enum.map(fn tt -> tt.block_number end) |> Enum.uniq()

    filtered_query = TokenTransfer.only_consensus_transfers_query()

    base_query =
      from(token_transfer in subquery(filtered_query),
        select: %{
          token_contract_address_hash: token_transfer.token_contract_address_hash,
          token_id: fragment("(?)[1]", token_transfer.token_ids),
          block_number: max(token_transfer.block_number)
        },
        group_by: [token_transfer.token_contract_address_hash, fragment("(?)[1]", token_transfer.token_ids)]
      )

    historical_token_transfers_query =
      Enum.reduce(token_transfers, base_query, fn tt, acc ->
        from(token_transfer in acc,
          or_where:
            token_transfer.token_contract_address_hash == ^tt.token_contract_address_hash and
              fragment("? @> ARRAY[?::decimal]", token_transfer.token_ids, ^tt.token_id) and
              token_transfer.block_number < ^tt.block_number and
              token_transfer.block_number not in ^non_consensus_block_numbers
        )
      end)

    refs_to_token_transfers = refs_to_token_transfers_query(historical_token_transfers_query, filtered_query)

    derived_token_transfers_query = derived_token_transfers_query(refs_to_token_transfers, filtered_query)

    changes =
      derived_token_transfers_query
      |> repo.all()
      |> Enum.reduce(changes_initial, fn tt, acc ->
        token_id = List.first(tt.token_ids)
        current_key = {tt.token_contract_address_hash, token_id}

        params = %{
          token_contract_address_hash: tt.token_contract_address_hash,
          token_id: token_id,
          owner_address_hash: tt.to_address_hash,
          owner_updated_at_block: tt.block_number,
          owner_updated_at_log_index: tt.log_index
        }

        Map.put(
          acc,
          current_key,
          Enum.max_by([acc[current_key], params], fn %{
                                                       owner_updated_at_block: block_number,
                                                       owner_updated_at_log_index: log_index
                                                     } ->
            {block_number, log_index}
          end)
        )
      end)
      |> Map.values()

    TokenInstances.insert(
      repo,
      changes,
      options
      |> Map.put(:timestamps, Import.timestamps())
      |> Map.put(:on_conflict, token_instances_on_conflict())
    )
  end

  defp forked_token_transfers_query(forked_transaction_hashes) do
    if DenormalizationHelper.tt_denormalization_finished?() do
      from(token_transfer in TokenTransfer,
        where: token_transfer.transaction_hash in ^forked_transaction_hashes,
        where: token_transfer.token_type == "ERC-721",
        inner_join: instance in Instance,
        on:
          fragment("? @> ARRAY[?::decimal]", token_transfer.token_ids, instance.token_id) and
            instance.token_contract_address_hash == token_transfer.token_contract_address_hash,
        # per one token instance we will have only one token transfer
        where:
          token_transfer.block_number == instance.owner_updated_at_block and
            token_transfer.log_index == instance.owner_updated_at_log_index,
        select: %{
          from: token_transfer.from_address_hash,
          to: token_transfer.to_address_hash,
          token_id: instance.token_id,
          token_contract_address_hash: token_transfer.token_contract_address_hash,
          block_number: token_transfer.block_number,
          log_index: token_transfer.log_index
        }
      )
    else
      from(token_transfer in TokenTransfer,
        where: token_transfer.transaction_hash in ^forked_transaction_hashes,
        inner_join: token in Token,
        on: token.contract_address_hash == token_transfer.token_contract_address_hash,
        where: token.type == "ERC-721",
        inner_join: instance in Instance,
        on:
          fragment("? @> ARRAY[?::decimal]", token_transfer.token_ids, instance.token_id) and
            instance.token_contract_address_hash == token_transfer.token_contract_address_hash,
        # per one token instance we will have only one token transfer
        where:
          token_transfer.block_number == instance.owner_updated_at_block and
            token_transfer.log_index == instance.owner_updated_at_log_index,
        select: %{
          from: token_transfer.from_address_hash,
          to: token_transfer.to_address_hash,
          token_id: instance.token_id,
          token_contract_address_hash: token_transfer.token_contract_address_hash,
          block_number: token_transfer.block_number,
          log_index: token_transfer.log_index
        }
      )
    end
  end

  defp refs_to_token_transfers_query(historical_token_transfers_query, filtered_query) do
    from(historical_tt in subquery(historical_token_transfers_query),
      inner_join: tt in subquery(filtered_query),
      on:
        tt.token_contract_address_hash == historical_tt.token_contract_address_hash and
          tt.block_number == historical_tt.block_number and
          fragment("? @> ARRAY[?::decimal]", tt.token_ids, historical_tt.token_id),
      select: %{
        token_contract_address_hash: tt.token_contract_address_hash,
        token_id: historical_tt.token_id,
        log_index: max(tt.log_index),
        block_number: tt.block_number
      },
      group_by: [tt.token_contract_address_hash, historical_tt.token_id, tt.block_number]
    )
  end

  defp derived_token_transfers_query(refs_to_token_transfers, filtered_query) do
    from(tt in filtered_query,
      inner_join: tt_1 in subquery(refs_to_token_transfers),
      on: tt_1.log_index == tt.log_index and tt_1.block_number == tt.block_number
    )
  end

  defp token_instances_on_conflict do
    from(
      token_instance in Instance,
      update: [
        set: [
          metadata: token_instance.metadata,
          error: token_instance.error,
          owner_updated_at_block: fragment("EXCLUDED.owner_updated_at_block"),
          owner_updated_at_log_index: fragment("EXCLUDED.owner_updated_at_log_index"),
          owner_address_hash: fragment("EXCLUDED.owner_address_hash"),
          inserted_at: fragment("LEAST(?, EXCLUDED.inserted_at)", token_instance.inserted_at),
          updated_at: fragment("GREATEST(?, EXCLUDED.updated_at)", token_instance.updated_at)
        ]
      ]
    )
  end

  defp derive_address_current_token_balances_grouped_query(deleted_address_current_token_balances) do
    initial_query =
      from(tb in Address.TokenBalance,
        select: %{
          address_hash: tb.address_hash,
          token_contract_address_hash: tb.token_contract_address_hash,
          token_id: tb.token_id,
          block_number: max(tb.block_number)
        },
        group_by: [tb.address_hash, tb.token_contract_address_hash, tb.token_id]
      )

    Enum.reduce(deleted_address_current_token_balances, initial_query, fn %{
                                                                            address_hash: address_hash,
                                                                            token_contract_address_hash:
                                                                              token_contract_address_hash,
                                                                            token_id: token_id
                                                                          },
                                                                          acc_query ->
      if token_id do
        from(tb in acc_query,
          or_where:
            tb.address_hash == ^address_hash and
              tb.token_contract_address_hash == ^token_contract_address_hash and
              tb.token_id == ^token_id
        )
      else
        from(tb in acc_query,
          or_where:
            tb.address_hash == ^address_hash and
              tb.token_contract_address_hash == ^token_contract_address_hash and
              is_nil(tb.token_id)
        )
      end
    end)
  end

  # `block_rewards` are linked to `blocks.hash`, but fetched by `blocks.number`, so when a block with the same number is
  # inserted, the old block rewards need to be deleted, so that the old and new rewards aren't combined.
  defp delete_rewards(repo, blocks_changes, %{timeout: timeout}) do
    {hashes, numbers} =
      Enum.reduce(blocks_changes, {[], []}, fn
        %{consensus: false, hash: hash}, {acc_hashes, acc_numbers} ->
          {[hash | acc_hashes], acc_numbers}

        %{consensus: true, number: number}, {acc_hashes, acc_numbers} ->
          {acc_hashes, [number | acc_numbers]}
      end)

    query =
      from(reward in Reward,
        inner_join: block in assoc(reward, :block),
        where: block.hash in ^hashes or block.number in ^numbers,
        # Enforce Reward ShareLocks order (see docs: sharelocks.md)
        order_by: [asc: :address_hash, asc: :address_type, asc: :block_hash],
        # acquire locks for `reward`s only
        lock: fragment("FOR UPDATE OF ?", reward)
      )

    delete_query =
      from(r in Reward,
        join: s in subquery(query),
        on:
          r.address_hash == s.address_hash and
            r.address_type == s.address_type and
            r.block_hash == s.block_hash
      )

    try do
      {count, nil} = repo.delete_all(delete_query, timeout: timeout)

      {:ok, count}
    rescue
      postgrex_error in Postgrex.Error ->
        {:error, %{exception: postgrex_error, blocks_changes: blocks_changes}}
    end
  end

  defp update_block_second_degree_relations(repo, uncle_hashes, %{
         timeout: timeout,
         timestamps: %{updated_at: updated_at}
       })
       when is_list(uncle_hashes) do
    query =
      from(
        bsdr in Block.SecondDegreeRelation,
        where: bsdr.uncle_hash in ^uncle_hashes,
        # Enforce SeconDegreeRelation ShareLocks order (see docs: sharelocks.md)
        order_by: [asc: :nephew_hash, asc: :uncle_hash],
        lock: "FOR NO KEY UPDATE"
      )

    update_query =
      from(
        b in Block.SecondDegreeRelation,
        join: s in subquery(query),
        on: b.nephew_hash == s.nephew_hash and b.uncle_hash == s.uncle_hash,
        update: [set: [uncle_fetched_at: ^updated_at]],
        select: map(b, [:nephew_hash, :uncle_hash, :index])
      )

    try do
      {_, result} = repo.update_all(update_query, [], timeout: timeout)

      {:ok, result}
    rescue
      postgrex_error in Postgrex.Error ->
        {:error, %{exception: postgrex_error, uncle_hashes: uncle_hashes}}
    end
  end

  defp where_forked(blocks_changes) when is_list(blocks_changes) do
    initial = from(t in Transaction, where: false)

    Enum.reduce(blocks_changes, initial, fn %{consensus: consensus, hash: hash, number: number}, acc ->
      if consensus do
        from(transaction in acc, or_where: transaction.block_hash != ^hash and transaction.block_number == ^number)
      else
        from(transaction in acc, or_where: transaction.block_hash == ^hash and transaction.block_number == ^number)
      end
    end)
  end

  defp where_invalid_neighbor(blocks_changes) when is_list(blocks_changes) do
    initial = from(b in Block, where: false)

    invalid_neighbors_query =
      Enum.reduce(blocks_changes, initial, fn %{
                                                consensus: consensus,
                                                hash: hash,
                                                parent_hash: parent_hash,
                                                number: number
                                              },
                                              acc ->
        previous_block_number = BlockNumberHelper.previous_block_number(number)
        next_block_number = BlockNumberHelper.next_block_number(number)

        if consensus do
          from(
            block in acc,
            or_where: block.number == ^previous_block_number and block.hash != ^parent_hash,
            or_where: block.number == ^next_block_number and block.parent_hash != ^hash
          )
        else
          acc
        end
      end)

    where(invalid_neighbors_query, [block], block.consensus)
  end

  defp celo_delete_epoch_rewards(_repo, [], _options), do: {:ok, []}

  defp celo_delete_epoch_rewards(repo, non_consensus_blocks, %{timeout: timeout}) do
    non_consensus_block_hashes = Enum.map(non_consensus_blocks, fn {_number, hash} -> hash end)

    ordered_query =
      from(epoch in CeloEpoch,
        where:
          epoch.start_processing_block_hash in ^non_consensus_block_hashes or
            epoch.end_processing_block_hash in ^non_consensus_block_hashes,
        # Enforce Epoch ShareLocks order (see docs: sharelocks.md)
        order_by: epoch.number,
        lock: "FOR UPDATE"
      )

    repo.all(ordered_query, timeout: timeout)

    epoch_rewards_query =
      from(reward in CeloEpochReward,
        join: epoch in subquery(ordered_query),
        on: reward.epoch_number == epoch.number
      )

    election_rewards_query =
      from(reward in CeloElectionReward,
        join: epoch in subquery(ordered_query),
        on: reward.epoch_number == epoch.number
      )

    repo.delete_all(epoch_rewards_query, timeout: timeout)
    repo.delete_all(election_rewards_query, timeout: timeout)

    {_count, updated_epochs} =
      repo.update_all(
        from(epoch in CeloEpoch,
          join: ordered_epoch in subquery(ordered_query),
          on: epoch.number == ordered_epoch.number,
          select: epoch
        ),
        [set: [fetched?: false]],
        timeout: timeout
      )

    {:ok, updated_epochs}
  end
end
