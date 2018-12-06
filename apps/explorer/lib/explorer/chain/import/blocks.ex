defmodule Explorer.Chain.Import.Blocks do
  @moduledoc """
  Bulk imports `t:Explorer.Chain.Block.t/0`.
  """

  require Ecto.Query

  import Ecto.Query, only: [from: 2, update: 2]

  alias Ecto.Adapters.SQL
  alias Ecto.{Changeset, Multi}
  alias Explorer.Chain.{Block, Import, InternalTransaction, Transaction}
  alias Explorer.Repo

  @behaviour Import.Runner

  # milliseconds
  @timeout 60_000

  @type imported :: [Block.t()]

  @impl Import.Runner
  def ecto_schema_module, do: Block

  @impl Import.Runner
  def option_key, do: :blocks

  @impl Import.Runner
  def imported_table_row do
    %{
      value_type: "[#{ecto_schema_module()}.t()]",
      value_description: "List of `t:#{ecto_schema_module()}.t/0`s"
    }
  end

  @impl Import.Runner
  def run(multi, changes_list, %{timestamps: timestamps} = options) do
    insert_options =
      options
      |> Map.get(option_key(), %{})
      |> Map.take(~w(on_conflict timeout)a)
      |> Map.put_new(:timeout, @timeout)
      |> Map.put(:timestamps, timestamps)

    where_forked = where_forked(changes_list)

    multi
    |> Multi.run(:derive_transaction_forks, fn _ ->
      derive_transaction_forks(%{
        timeout: options[Import.Transaction.Forks.option_key()][:timeout] || Import.Transaction.Forks.timeout(),
        timestamps: timestamps,
        where_forked: where_forked
      })
    end)
    # MUST be after `:derive_transaction_forks`, which depends on values in `transactions` table
    |> Multi.run(:fork_transactions, fn _ ->
      fork_transactions(%{
        timeout: options[Import.Transactions.option_key()][:timeout] || Import.Transactions.timeout(),
        timestamps: timestamps,
        where_forked: where_forked
      })
    end)
    |> Multi.run(:lose_consenus, fn _ ->
      lose_consensus(changes_list, insert_options)
    end)
    |> Multi.run(:blocks, fn _ ->
      insert(changes_list, insert_options)
    end)
    |> Multi.run(:uncle_fetched_block_second_degree_relations, fn %{blocks: blocks} when is_list(blocks) ->
      update_block_second_degree_relations(
        blocks,
        %{
          timeout:
            options[Import.Block.SecondDegreeRelations.option_key()][:timeout] ||
              Import.Block.SecondDegreeRelations.timeout(),
          timestamps: timestamps
        }
      )
    end)
    |> Multi.run(
      :internal_transaction_transaction_block_number,
      fn %{blocks: blocks} ->
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

        {total, _} = Repo.update_all(query, [])

        {:ok, total}
      end
    )
  end

  @impl Import.Runner
  def timeout, do: @timeout

  # sobelow_skip ["SQL.Query"]
  defp derive_transaction_forks(%{
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
        ]
      )

    {select_sql, parameters} = SQL.to_sql(:all, Repo, query)

    insert_sql = """
    INSERT INTO transaction_forks (uncle_hash, index, hash, inserted_at, updated_at)
    #{select_sql}
    RETURNING uncle_hash, hash
    """

    with {:ok, %Postgrex.Result{columns: ["uncle_hash", "hash"], command: :insert, rows: rows}} <-
           SQL.query(
             Repo,
             insert_sql,
             parameters,
             timeout: timeout
           ) do
      derived_transaction_forks = Enum.map(rows, fn [uncle_hash, hash] -> %{uncle_hash: uncle_hash, hash: hash} end)

      {:ok, derived_transaction_forks}
    end
  end

  defp fork_transactions(%{timeout: timeout, timestamps: %{updated_at: updated_at}, where_forked: where_forked}) do
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

    try do
      {_, result} = Repo.update_all(query, [], timeout: timeout, returning: [:hash])

      {:ok, result}
    rescue
      postgrex_error in Postgrex.Error ->
        {:error, %{exception: postgrex_error}}
    end
  end

  @spec insert([map()], %{
          optional(:on_conflict) => Import.Runner.on_conflict(),
          required(:timeout) => timeout,
          required(:timestamps) => Import.timestamps()
        }) :: {:ok, [Block.t()]} | {:error, [Changeset.t()]}
  defp insert(changes_list, %{timeout: timeout, timestamps: timestamps} = options) when is_list(changes_list) do
    on_conflict = Map.get_lazy(options, :on_conflict, &default_on_conflict/0)

    # order so that row ShareLocks are grabbed in a consistent order
    ordered_changes_list = Enum.sort_by(changes_list, &{&1.number, &1.hash})

    Import.insert_changes_list(
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
      ]
    )
  end

  defp lose_consensus(blocks_changes, %{timeout: timeout, timestamps: %{updated_at: updated_at}})
       when is_list(blocks_changes) do
    ordered_consensus_block_number =
      blocks_changes
      |> Enum.reduce(MapSet.new(), fn
        %{consensus: true, number: number}, acc ->
          MapSet.put(acc, number)

        %{consensus: false}, acc ->
          acc
      end)
      |> Enum.sort()

    query =
      from(
        block in Block,
        where: block.number in ^ordered_consensus_block_number,
        update: [
          set: [
            consensus: false,
            updated_at: ^updated_at
          ]
        ]
      )

    try do
      {_, result} = Repo.update_all(query, [], timeout: timeout, returning: [:hash, :number])

      {:ok, result}
    rescue
      postgrex_error in Postgrex.Error ->
        {:error, %{exception: postgrex_error, consensus_block_numbers: ordered_consensus_block_number}}
    end
  end

  defp update_block_second_degree_relations(blocks, %{timeout: timeout, timestamps: %{updated_at: updated_at}})
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
      {count, _} = Repo.update_all(query, [], timeout: timeout)

      {:ok, count}
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
