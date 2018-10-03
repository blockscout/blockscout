defmodule Explorer.Chain.Import.Blocks do
  @moduledoc """
  Bulk imports `t:Explorer.Chain.Block.t/0`.
  """

  require Ecto.Query

  import Ecto.Query, only: [from: 2, update: 2]

  alias Ecto.{Changeset, Multi}
  alias Ecto.Adapters.SQL
  alias Explorer.Chain.{Block, Import, Transaction}
  alias Explorer.Repo

  # milliseconds
  @timeout 60_000

  @type options :: %{
          required(:params) => Import.params(),
          optional(:timeout) => timeout
        }
  @type imported :: [Block.t()]

  def run(multi, ecto_schema_module_to_changes_list_map, options)
      when is_map(ecto_schema_module_to_changes_list_map) and is_map(options) do
    case ecto_schema_module_to_changes_list_map do
      %{Block => blocks_changes} ->
        timestamps = Map.fetch!(options, :timestamps)
        blocks_timeout = options[:blocks][:timeout] || @timeout
        where_forked = where_forked(blocks_changes)

        multi
        |> Multi.run(:derive_transaction_forks, fn _ ->
          derive_transaction_forks(%{
            timeout: options[:transaction_forks][:timeout] || Import.transaction_forks_timeout(),
            timestamps: timestamps,
            where_forked: where_forked
          })
        end)
        # MUST be after `:derive_transaction_forks`, which depends on values in `transactions` table
        |> Multi.run(:fork_transactions, fn _ ->
          fork_transactions(%{
            timeout: options[:transactions][:timeout] || Import.transactions_timeout(),
            timestamps: timestamps,
            where_forked: where_forked
          })
        end)
        |> Multi.run(:lose_consenus, fn _ ->
          lose_consensus(blocks_changes, %{timeout: blocks_timeout, timestamps: timestamps})
        end)
        |> Multi.run(:blocks, fn _ ->
          insert(blocks_changes, %{timeout: blocks_timeout, timestamps: timestamps})
        end)
        |> Multi.run(:uncle_fetched_block_second_degree_relations, fn %{blocks: blocks} when is_list(blocks) ->
          update_block_second_degree_relations(
            blocks,
            %{
              timeout:
                options[:block_second_degree_relations][:timeout] || Import.Block.SecondDegreeRelations.timeout(),
              timestamps: timestamps
            }
          )
        end)

      _ ->
        multi
    end
  end

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

  @spec insert([map()], %{required(:timeout) => timeout, required(:timestamps) => Import.timestamps()}) ::
          {:ok, [Block.t()]} | {:error, [Changeset.t()]}
  defp insert(changes_list, %{timeout: timeout, timestamps: timestamps})
       when is_list(changes_list) do
    # order so that row ShareLocks are grabbed in a consistent order
    ordered_changes_list = Enum.sort_by(changes_list, &{&1.number, &1.hash})

    {:ok, blocks} =
      Import.insert_changes_list(
        ordered_changes_list,
        conflict_target: :hash,
        on_conflict: :replace_all,
        for: Block,
        returning: true,
        timeout: timeout,
        timestamps: timestamps
      )

    {:ok, blocks}
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
      {_, result} = Repo.update_all(query, [], timeout: timeout)

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
