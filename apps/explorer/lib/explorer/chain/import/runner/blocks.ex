defmodule Explorer.Chain.Import.Runner.Blocks do
  @moduledoc """
  Bulk imports `t:Explorer.Chain.Block.t/0`.
  """

  require Ecto.Query

  import Ecto.Query, only: [from: 2, select: 2, subquery: 1, update: 2]

  alias Ecto.Adapters.SQL
  alias Ecto.{Changeset, Multi, Repo}
  alias Explorer.Chain.{Address, Block, Hash, Import, InternalTransaction, Transaction}
  alias Explorer.Chain.Block.Reward
  alias Explorer.Chain.Import.Runner
  alias Explorer.Chain.Import.Runner.Address.CurrentTokenBalances
  alias Explorer.Chain.Import.Runner.Tokens

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

    ordered_consensus_block_numbers = ordered_consensus_block_numbers(changes_list)
    where_forked = where_forked(changes_list)

    multi
    |> Multi.run(:derive_transaction_forks, fn repo, _ ->
      derive_transaction_forks(%{
        repo: repo,
        timeout: options[Runner.Transaction.Forks.option_key()][:timeout] || Runner.Transaction.Forks.timeout(),
        timestamps: timestamps,
        where_forked: where_forked
      })
    end)
    # MUST be after `:derive_transaction_forks`, which depends on values in `transactions` table
    |> Multi.run(:fork_transactions, fn repo, _ ->
      fork_transactions(%{
        repo: repo,
        timeout: options[Runner.Transactions.option_key()][:timeout] || Runner.Transactions.timeout(),
        timestamps: timestamps,
        where_forked: where_forked
      })
    end)
    |> Multi.run(:lose_consensus, fn repo, _ ->
      lose_consensus(repo, ordered_consensus_block_numbers, insert_options)
    end)
    |> Multi.run(:delete_address_token_balances, fn repo, _ ->
      delete_address_token_balances(repo, ordered_consensus_block_numbers, insert_options)
    end)
    |> Multi.run(:delete_address_current_token_balances, fn repo, _ ->
      delete_address_current_token_balances(repo, ordered_consensus_block_numbers, insert_options)
    end)
    |> Multi.run(:derive_address_current_token_balances, fn repo,
                                                            %{
                                                              delete_address_current_token_balances:
                                                                deleted_address_current_token_balances
                                                            } ->
      derive_address_current_token_balances(repo, deleted_address_current_token_balances, insert_options)
    end)
    |> Multi.run(:blocks_update_token_holder_counts, fn repo,
                                                        %{
                                                          delete_address_current_token_balances: deleted,
                                                          derive_address_current_token_balances: inserted
                                                        } ->
      deltas = CurrentTokenBalances.token_holder_count_deltas(%{deleted: deleted, inserted: inserted})
      Tokens.update_holder_counts_with_deltas(repo, deltas, insert_options)
    end)
    |> Multi.run(:delete_rewards, fn repo, _ ->
      delete_rewards(repo, changes_list, insert_options)
    end)
    |> Multi.run(:blocks, fn repo, _ ->
      insert(repo, changes_list, insert_options)
    end)
    |> Multi.run(:uncle_fetched_block_second_degree_relations, fn repo, %{blocks: blocks} when is_list(blocks) ->
      update_block_second_degree_relations(
        repo,
        blocks,
        %{
          timeout:
            options[Runner.Block.SecondDegreeRelations.option_key()][:timeout] ||
              Runner.Block.SecondDegreeRelations.timeout(),
          timestamps: timestamps
        }
      )
    end)
    |> Multi.run(
      :internal_transaction_transaction_block_number,
      fn repo, %{blocks: blocks} ->
        blocks_hashes = Enum.map(blocks, & &1.hash)

        query =
          from(
            internal_transaction in InternalTransaction,
            join: transaction in Transaction,
            on: internal_transaction.transaction_hash == transaction.hash,
            join: block in Block,
            on: block.hash == transaction.block_hash,
            where: block.hash in ^blocks_hashes,
            update: [
              set: [
                block_number: block.number
              ]
            ]
          )

        {total, _} = repo.update_all(query, [])

        {:ok, total}
      end
    )
  end

  @impl Runner
  def timeout, do: @timeout

  # sobelow_skip ["SQL.Query"]
  defp derive_transaction_forks(%{
         repo: repo,
         timeout: timeout,
         timestamps: %{inserted_at: inserted_at, updated_at: updated_at},
         where_forked: where_forked
       }) do
    query =
      from(transaction in where_forked,
        select: [
          transaction.block_hash,
          transaction.index,
          transaction.hash,
          type(^inserted_at, transaction.inserted_at),
          type(^updated_at, transaction.updated_at)
        ],
        # order so that row ShareLocks are grabbed in a consistent order with
        # `Explorer.Chain.Import.Runner.Transactions.insert`
        order_by: transaction.hash
      )

    {select_sql, parameters} = SQL.to_sql(:all, repo, query)

    insert_sql = """
    INSERT INTO transaction_forks (uncle_hash, index, hash, inserted_at, updated_at)
    #{select_sql}
    ON CONFLICT (uncle_hash, index)
    DO UPDATE SET hash = EXCLUDED.hash
    WHERE EXCLUDED.hash <> transaction_forks.hash
    RETURNING uncle_hash, hash
    """

    with {:ok, %Postgrex.Result{columns: ["uncle_hash", "hash"], command: :insert, rows: rows}} <-
           SQL.query(
             repo,
             insert_sql,
             parameters,
             timeout: timeout
           ) do
      derived_transaction_forks = Enum.map(rows, fn [uncle_hash, hash] -> %{uncle_hash: uncle_hash, hash: hash} end)

      {:ok, derived_transaction_forks}
    end
  end

  defp fork_transactions(%{
         repo: repo,
         timeout: timeout,
         timestamps: %{updated_at: updated_at},
         where_forked: where_forked
       }) do
    query =
      where_forked
      |> update(
        set: [
          block_hash: nil,
          block_number: nil,
          gas_used: nil,
          cumulative_gas_used: nil,
          index: nil,
          internal_transactions_indexed_at: nil,
          status: nil,
          error: nil,
          updated_at: ^updated_at
        ]
      )
      |> select([:hash])

    try do
      {_, result} = repo.update_all(query, [], timeout: timeout)

      {:ok, result}
    rescue
      postgrex_error in Postgrex.Error ->
        {:error, %{exception: postgrex_error}}
    end
  end

  @spec insert(Repo.t(), [map()], %{
          optional(:on_conflict) => Runner.on_conflict(),
          required(:timeout) => timeout,
          required(:timestamps) => Import.timestamps()
        }) :: {:ok, [Block.t()]} | {:error, [Changeset.t()]}
  defp insert(repo, changes_list, %{timeout: timeout, timestamps: timestamps} = options) when is_list(changes_list) do
    on_conflict = Map.get_lazy(options, :on_conflict, &default_on_conflict/0)

    # order so that row ShareLocks are grabbed in a consistent order
    ordered_changes_list = Enum.sort_by(changes_list, &{&1.number, &1.hash})

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

  defp ordered_consensus_block_numbers(blocks_changes) when is_list(blocks_changes) do
    blocks_changes
    |> Enum.reduce(MapSet.new(), fn
      %{consensus: true, number: number}, acc ->
        MapSet.put(acc, number)

      %{consensus: false}, acc ->
        acc
    end)
    |> Enum.sort()
  end

  defp lose_consensus(_, [], _), do: {:ok, []}

  defp lose_consensus(repo, ordered_consensus_block_number, %{timeout: timeout, timestamps: %{updated_at: updated_at}})
       when is_list(ordered_consensus_block_number) do
    query =
      from(
        block in Block,
        where: block.number in ^ordered_consensus_block_number,
        update: [
          set: [
            consensus: false,
            updated_at: ^updated_at
          ]
        ],
        select: [:hash, :number]
      )

    try do
      {_, result} = repo.update_all(query, [], timeout: timeout)

      {:ok, result}
    rescue
      postgrex_error in Postgrex.Error ->
        {:error, %{exception: postgrex_error, consensus_block_numbers: ordered_consensus_block_number}}
    end
  end

  defp delete_address_token_balances(_, [], _), do: {:ok, []}

  defp delete_address_token_balances(repo, ordered_consensus_block_numbers, %{timeout: timeout}) do
    ordered_query =
      from(address_token_balance in Address.TokenBalance,
        where: address_token_balance.block_number in ^ordered_consensus_block_numbers,
        select: map(address_token_balance, [:address_hash, :token_contract_address_hash, :block_number]),
        # MUST match order in `Explorer.Chain.Import.Runner.Address.TokenBalances.insert` to prevent ShareLock ordering deadlocks.
        order_by: [
          address_token_balance.address_hash,
          address_token_balance.token_contract_address_hash,
          address_token_balance.block_number
        ],
        # ensures rows remains locked while outer query is joining to it
        lock: "FOR UPDATE"
      )

    query =
      from(address_token_balance in Address.TokenBalance,
        select: map(address_token_balance, [:address_hash, :token_contract_address_hash, :block_number]),
        inner_join: ordered_address_token_balance in subquery(ordered_query),
        on:
          ordered_address_token_balance.address_hash == address_token_balance.address_hash and
            ordered_address_token_balance.token_contract_address_hash ==
              address_token_balance.token_contract_address_hash and
            ordered_address_token_balance.block_number == address_token_balance.block_number
      )

    try do
      {_count, deleted_address_token_balances} = repo.delete_all(query, timeout: timeout)

      {:ok, deleted_address_token_balances}
    rescue
      postgrex_error in Postgrex.Error ->
        {:error, %{exception: postgrex_error, block_numbers: ordered_consensus_block_numbers}}
    end
  end

  defp delete_address_current_token_balances(_, [], _), do: {:ok, []}

  defp delete_address_current_token_balances(repo, ordered_consensus_block_numbers, %{timeout: timeout}) do
    ordered_query =
      from(address_current_token_balance in Address.CurrentTokenBalance,
        where: address_current_token_balance.block_number in ^ordered_consensus_block_numbers,
        select: map(address_current_token_balance, [:address_hash, :token_contract_address_hash]),
        # MUST match order in `Explorer.Chain.Import.Runner.Address.CurrentTokenBalances.insert` to prevent ShareLock ordering deadlocks.
        order_by: [
          address_current_token_balance.address_hash,
          address_current_token_balance.token_contract_address_hash
        ],
        # ensures row remains locked while outer query is joining to it
        lock: "FOR UPDATE"
      )

    query =
      from(address_current_token_balance in Address.CurrentTokenBalance,
        select:
          map(address_current_token_balance, [
            :address_hash,
            :token_contract_address_hash,
            # Used to determine if `address_hash` was a holder of `token_contract_address_hash` before

            # `address_current_token_balance` is deleted in `update_tokens_holder_count`.
            :value
          ]),
        inner_join: ordered_address_current_token_balance in subquery(ordered_query),
        on:
          ordered_address_current_token_balance.address_hash == address_current_token_balance.address_hash and
            ordered_address_current_token_balance.token_contract_address_hash ==
              address_current_token_balance.token_contract_address_hash
      )

    try do
      {_count, deleted_address_current_token_balances} = repo.delete_all(query, timeout: timeout)

      {:ok, deleted_address_current_token_balances}
    rescue
      postgrex_error in Postgrex.Error ->
        {:error, %{exception: postgrex_error, block_numbers: ordered_consensus_block_numbers}}
    end
  end

  defp derive_address_current_token_balances(_, [], _), do: {:ok, []}

  # sobelow_skip ["SQL.Query"]
  defp derive_address_current_token_balances(repo, deleted_address_current_token_balances, %{timeout: timeout})
       when is_list(deleted_address_current_token_balances) do
    initial_query =
      from(address_token_balance in Address.TokenBalance,
        select: %{
          address_hash: address_token_balance.address_hash,
          token_contract_address_hash: address_token_balance.token_contract_address_hash,
          block_number: max(address_token_balance.block_number)
        },
        group_by: [address_token_balance.address_hash, address_token_balance.token_contract_address_hash]
      )

    final_query =
      Enum.reduce(deleted_address_current_token_balances, initial_query, fn %{
                                                                              address_hash: address_hash,
                                                                              token_contract_address_hash:
                                                                                token_contract_address_hash
                                                                            },
                                                                            acc_query ->
        from(address_token_balance in acc_query,
          or_where:
            address_token_balance.address_hash == ^address_hash and
              address_token_balance.token_contract_address_hash == ^token_contract_address_hash
        )
      end)

    new_current_token_balance_query =
      from(new_current_token_balance in subquery(final_query),
        inner_join: address_token_balance in Address.TokenBalance,
        on:
          address_token_balance.address_hash == new_current_token_balance.address_hash and
            address_token_balance.token_contract_address_hash == new_current_token_balance.token_contract_address_hash and
            address_token_balance.block_number == new_current_token_balance.block_number,
        select: {
          new_current_token_balance.address_hash,
          new_current_token_balance.token_contract_address_hash,
          new_current_token_balance.block_number,
          address_token_balance.value,
          over(min(address_token_balance.inserted_at), :w),
          over(max(address_token_balance.updated_at), :w)
        },
        # Prevent ShareLock deadlock by matching order of `Explorer.Chain.Import.Runner.Address.CurrentTokenBalances.insert`
        order_by: [new_current_token_balance.address_hash, new_current_token_balance.token_contract_address_hash],
        windows: [
          w: [partition_by: [address_token_balance.address_hash, address_token_balance.token_contract_address_hash]]
        ]
      )

    {select_sql, parameters} = SQL.to_sql(:all, repo, new_current_token_balance_query)

    # No `ON CONFLICT` because `delete_address_current_token_balances` should have removed any conflicts.
    insert_sql = """
    INSERT INTO address_current_token_balances (address_hash, token_contract_address_hash, block_number, value, inserted_at, updated_at)
    #{select_sql}
    RETURNING address_hash, token_contract_address_hash, block_number, value
    """

    with {:ok,
          %Postgrex.Result{
            columns: [
              "address_hash",
              "token_contract_address_hash",
              "block_number",
              # needed for `update_tokens_holder_count`
              "value"
            ],
            command: :insert,
            rows: rows
          }} <- SQL.query(repo, insert_sql, parameters, timeout: timeout) do
      derived_address_current_token_balances =
        Enum.map(rows, fn [address_hash_bytes, token_contract_address_hash_bytes, block_number, value] ->
          {:ok, address_hash} = Hash.Address.load(address_hash_bytes)
          {:ok, token_contract_address_hash} = Hash.Address.load(token_contract_address_hash_bytes)

          %{
            address_hash: address_hash,
            token_contract_address_hash: token_contract_address_hash,
            block_number: block_number,
            value: value
          }
        end)

      {:ok, derived_address_current_token_balances}
    end
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
        where: block.hash in ^hashes or block.number in ^numbers
      )

    try do
      {count, nil} = repo.delete_all(query, timeout: timeout)

      {:ok, count}
    rescue
      postgrex_error in Postgrex.Error ->
        {:error, %{exception: postgrex_error, blocks_changes: blocks_changes}}
    end
  end

  defp update_block_second_degree_relations(repo, blocks, %{timeout: timeout, timestamps: %{updated_at: updated_at}})
       when is_list(blocks) do
    ordered_uncle_hashes =
      blocks
      |> MapSet.new(& &1.hash)
      |> Enum.sort()

    query =
      from(
        bsdr in Block.SecondDegreeRelation,
        where: bsdr.uncle_hash in ^ordered_uncle_hashes,
        update: [
          set: [
            uncle_fetched_at: ^updated_at
          ]
        ]
      )

    try do
      {_, result} = repo.update_all(query, [], timeout: timeout)

      {:ok, result}
    rescue
      postgrex_error in Postgrex.Error ->
        {:error, %{exception: postgrex_error, uncle_hashes: ordered_uncle_hashes}}
    end
  end

  defp where_forked(blocks_changes) when is_list(blocks_changes) do
    initial = from(t in Transaction, where: false)

    Enum.reduce(blocks_changes, initial, fn %{consensus: consensus, hash: hash, number: number}, acc ->
      case consensus do
        false ->
          from(transaction in acc, or_where: transaction.block_hash == ^hash and transaction.block_number == ^number)

        true ->
          from(transaction in acc, or_where: transaction.block_hash != ^hash and transaction.block_number == ^number)
      end
    end)
  end
end
