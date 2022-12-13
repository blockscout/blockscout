defmodule Explorer.Chain.Import.Runner.Blocks do
  @moduledoc """
  Bulk imports `t:Explorer.Chain.Block.t/0`.
  """

  require Ecto.Query
  require Logger

  import Ecto.Query, only: [from: 2]

  alias Ecto.{Changeset, Multi, Repo}
  alias Explorer.Chain.{Block, Import, PendingBlockOperation, Transaction}
  alias Explorer.Chain.Block.Reward
  alias Explorer.Chain.Import.Runner
  alias Explorer.Prometheus.Instrumenter
  alias Explorer.Repo, as: ExplorerRepo

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
    Logger.info(["### Blocks run STARTED length #{Enum.count(changes_list)} ###"])

    insert_options =
      options
      |> Map.get(option_key(), %{})
      |> Map.take(~w(on_conflict timeout)a)
      |> Map.put_new(:timeout, @timeout)
      |> Map.put(:timestamps, timestamps)

    hashes = Enum.map(changes_list, & &1.hash)

    minimal_block_height = trace_minimal_block_height()

    hashes_for_pending_block_operations =
      if minimal_block_height > 0 do
        changes_list
        |> Enum.filter(&(&1.number >= minimal_block_height))
        |> Enum.map(& &1.hash)
      else
        hashes
      end

    consensus_block_numbers = consensus_block_numbers(changes_list)

    # Enforce ShareLocks tables order (see docs: sharelocks.md)
    run_func = fn repo ->
      {:ok, nonconsensus_items} = lose_consensus(repo, hashes, consensus_block_numbers, changes_list, insert_options)

      nonconsensus_hashes =
        if minimal_block_height > 0 do
          nonconsensus_items
          |> Enum.filter(fn {number, _hash} -> number >= minimal_block_height end)
          |> Enum.map(fn {_number, hash} -> hash end)
        else
          hashes
        end

      {:ok, nonconsensus_hashes}
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
    |> Multi.run(:new_pending_operations, fn repo, %{lose_consensus: nonconsensus_hashes} ->
      Instrumenter.block_import_stage_runner(
        fn ->
          new_pending_operations(repo, nonconsensus_hashes, hashes_for_pending_block_operations, insert_options)
        end,
        :address_referencing,
        :blocks,
        :new_pending_operations
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
  end

  @impl Runner
  def timeout, do: @timeout

  defp fork_transactions(%{
         repo: repo,
         timeout: timeout,
         timestamps: %{updated_at: updated_at},
         blocks_changes: blocks_changes
       }) do
    Logger.info(["### Blocks fork_transactions STARTED ###"])

    query =
      from(
        transaction in where_forked(blocks_changes),
        select: transaction,
        # Enforce Transaction ShareLocks order (see docs: sharelocks.md)
        order_by: [asc: :hash],
        lock: "FOR UPDATE"
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
            updated_at: ^updated_at
          ]
        ],
        select: s
      )

    {_num, transactions} = repo.update_all(update_query, [], timeout: timeout)

    Logger.info(["### Blocks fork_transactions FINISHED ###"])

    {:ok, transactions}
  rescue
    postgrex_error in Postgrex.Error ->
      Logger.info(["### Blocks fork_transactions ERROR ###"])
      {:error, %{exception: postgrex_error}}
  end

  defp derive_transaction_forks(%{
         repo: repo,
         timeout: timeout,
         timestamps: %{inserted_at: inserted_at, updated_at: updated_at},
         transactions: transactions
       }) do
    Logger.info(["### Blocks derive_transaction_forks STARTED ###"])

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

    Logger.info(["### Blocks derive_transaction_forks length #{Enum.count(transaction_forks)} ###"])

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

    Logger.info(["### Blocks derive_transaction_forks FINISHED ###"])

    {:ok, Enum.map(forked_transaction, & &1.hash)}
  end

  @spec insert(Repo.t(), [map()], %{
          optional(:on_conflict) => Runner.on_conflict(),
          required(:timeout) => timeout,
          required(:timestamps) => Import.timestamps()
        }) :: {:ok, [Block.t()]} | {:error, [Changeset.t()]}
  defp insert(repo, changes_list, %{timeout: timeout, timestamps: timestamps} = options) when is_list(changes_list) do
    Logger.info(["### Blocks insert STARTED ###"])
    on_conflict = Map.get_lazy(options, :on_conflict, &default_on_conflict/0)

    # Enforce Block ShareLocks order (see docs: sharelocks.md)
    ordered_changes_list =
      changes_list
      |> Enum.sort_by(& &1.hash)
      |> Enum.dedup_by(& &1.hash)

    Logger.info(["### Blocks insert length #{Enum.count(ordered_changes_list)} ###"])

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

  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  defp default_on_conflict do
    from(
      block in Block,
      update: [
        set: [
          consensus: fragment("EXCLUDED.consensus"),
          difficulty: fragment("EXCLUDED.difficulty"),
          gas_limit: fragment("EXCLUDED.gas_limit"),
          gas_used: fragment("EXCLUDED.gas_used"),
          miner_hash: fragment("EXCLUDED.miner_hash"),
          nonce: fragment("EXCLUDED.nonce"),
          number: fragment("EXCLUDED.number"),
          parent_hash: fragment("EXCLUDED.parent_hash"),
          size: fragment("EXCLUDED.size"),
          timestamp: fragment("EXCLUDED.timestamp"),
          total_difficulty: fragment("EXCLUDED.total_difficulty"),
          base_fee_per_gas: fragment("EXCLUDED.base_fee_per_gas"),
          is_empty: fragment("EXCLUDED.is_empty"),
          # Don't update `hash` as it is used for the conflict target
          inserted_at: fragment("LEAST(?, EXCLUDED.inserted_at)", block.inserted_at),
          updated_at: fragment("GREATEST(?, EXCLUDED.updated_at)", block.updated_at)
        ]
      ],
      where:
        fragment("EXCLUDED.consensus <> ?", block.consensus) or fragment("EXCLUDED.difficulty <> ?", block.difficulty) or
          fragment("EXCLUDED.gas_limit <> ?", block.gas_limit) or fragment("EXCLUDED.gas_used <> ?", block.gas_used) or
          fragment("EXCLUDED.miner_hash <> ?", block.miner_hash) or fragment("EXCLUDED.nonce <> ?", block.nonce) or
          fragment("EXCLUDED.number <> ?", block.number) or fragment("EXCLUDED.parent_hash <> ?", block.parent_hash) or
          fragment("EXCLUDED.size <> ?", block.size) or fragment("EXCLUDED.timestamp <> ?", block.timestamp) or
          fragment("EXCLUDED.total_difficulty <> ?", block.total_difficulty)
    )
  end

  defp consensus_block_numbers(blocks_changes) when is_list(blocks_changes) do
    blocks_changes
    |> Enum.filter(& &1.consensus)
    |> Enum.map(& &1.number)
  end

  def lose_consensus(repo, hashes, consensus_block_numbers, changes_list, %{
        timeout: timeout,
        timestamps: %{updated_at: updated_at}
      }) do
    Logger.info(["### Blocks lose_consensus STARTED ###"])

    acquire_query =
      from(
        block in where_invalid_neighbour(changes_list),
        or_where: block.number in ^consensus_block_numbers,
        # we also need to acquire blocks that will be upserted here, for ordering
        or_where: block.hash in ^hashes,
        select: block.hash,
        # Enforce Block ShareLocks order (see docs: sharelocks.md)
        order_by: [asc: block.hash],
        lock: "FOR UPDATE"
      )

    {_, removed_consensus_block_hashes} =
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

    Logger.info(["### Blocks lose_consensus FINISHED ###"])

    {:ok, removed_consensus_block_hashes}
  rescue
    postgrex_error in Postgrex.Error ->
      Logger.info(["### Blocks lose_consensus ERROR ###"])
      {:error, %{exception: postgrex_error, consensus_block_numbers: consensus_block_numbers}}
  end

  def invalidate_consensus_blocks(block_numbers) do
    opts = %{
      timeout: 60_000,
      timestamps: %{updated_at: DateTime.utc_now()}
    }

    lose_consensus(ExplorerRepo, [], block_numbers, [], opts)
  end

  defp trace_minimal_block_height do
    EthereumJSONRPC.first_block_to_fetch(:trace_first_block)
  end

  defp new_pending_operations(repo, nonconsensus_hashes, hashes, %{
         timeout: timeout,
         timestamps: timestamps
       }) do
    Logger.info(["### Blocks new_pending_operations STARTED ###"])

    if Application.get_env(:explorer, :json_rpc_named_arguments)[:variant] == EthereumJSONRPC.RSK do
      {:ok, []}
    else
      sorted_pending_ops =
        nonconsensus_hashes
        |> MapSet.new()
        |> MapSet.union(MapSet.new(hashes))
        |> Enum.sort()
        |> Enum.map(fn hash ->
          %{block_hash: hash}
        end)

      Logger.info(["### Blocks new_pending_operations length #{Enum.count(sorted_pending_ops)} ###"])

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
    end
  end

  # `block_rewards` are linked to `blocks.hash`, but fetched by `blocks.number`, so when a block with the same number is
  # inserted, the old block rewards need to be deleted, so that the old and new rewards aren't combined.
  defp delete_rewards(repo, blocks_changes, %{timeout: timeout}) do
    Logger.info(["### Blocks delete_rewards STARTED ###"])

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

      Logger.info(["### Blocks delete_rewards FINISHED ###"])
      {:ok, count}
    rescue
      postgrex_error in Postgrex.Error ->
        Logger.info(["### Blocks delete_rewards ERROR ###"])
        {:error, %{exception: postgrex_error, blocks_changes: blocks_changes}}
    end
  end

  defp update_block_second_degree_relations(repo, uncle_hashes, %{
         timeout: timeout,
         timestamps: %{updated_at: updated_at}
       })
       when is_list(uncle_hashes) do
    Logger.info(["### Blocks update_block_second_degree_relations STARTED ###"])

    query =
      from(
        bsdr in Block.SecondDegreeRelation,
        where: bsdr.uncle_hash in ^uncle_hashes,
        # Enforce SeconDegreeRelation ShareLocks order (see docs: sharelocks.md)
        order_by: [asc: :nephew_hash, asc: :uncle_hash],
        lock: "FOR UPDATE"
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

      Logger.info(["### Blocks update_block_second_degree_relations FINISHED ###"])
      {:ok, result}
    rescue
      postgrex_error in Postgrex.Error ->
        Logger.info(["### Blocks update_block_second_degree_relations ERROR ###"])
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

  defp where_invalid_neighbour(blocks_changes) when is_list(blocks_changes) do
    initial = from(b in Block, where: false)

    Enum.reduce(blocks_changes, initial, fn %{
                                              consensus: consensus,
                                              hash: hash,
                                              parent_hash: parent_hash,
                                              number: number
                                            },
                                            acc ->
      if consensus do
        from(
          block in acc,
          or_where: block.number == ^(number - 1) and block.hash != ^parent_hash,
          or_where: block.number == ^(number + 1) and block.parent_hash != ^hash
        )
      else
        acc
      end
    end)
  end
end
