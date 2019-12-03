defmodule Explorer.Chain.Import.Runner.InternalTransactions do
  @moduledoc """
  Bulk imports `t:Explorer.Chain.InternalTransactions.t/0`.
  """

  require Ecto.Query
  require Logger

  alias Ecto.{Changeset, Multi, Repo}
  alias Explorer.Chain.{Block, Hash, Import, InternalTransaction, Transaction}
  alias Explorer.Chain.Import.Runner

  import Ecto.Query, only: [from: 2]

  @behaviour Runner

  # milliseconds
  @timeout 60_000

  @type imported :: [
          %{required(:index) => non_neg_integer(), required(:transaction_hash) => Hash.Full.t()}
        ]

  @impl Runner
  def ecto_schema_module, do: InternalTransaction

  @impl Runner
  def option_key, do: :internal_transactions

  @impl Runner
  def imported_table_row do
    %{
      value_type: "[%{index: non_neg_integer(), transaction_hash: Explorer.Chain.Hash.t()}]",
      value_description: "List of maps of the `t:Explorer.Chain.InternalTransaction.t/0` `index` and `transaction_hash`"
    }
  end

  @impl Runner
  def run(multi, changes_list, %{timestamps: timestamps} = options) when is_map(options) do
    insert_options =
      options
      |> Map.get(option_key(), %{})
      |> Map.take(~w(on_conflict timeout)a)
      |> Map.put_new(:timeout, @timeout)
      |> Map.put(:timestamps, timestamps)

    changes_list_without_first_traces = Enum.reject(changes_list, fn changes -> changes[:index] == 0 end)
    first_traces = Enum.filter(changes_list, fn changes -> changes[:index] == 0 end)

    transactions_timeout = options[Runner.Transactions.option_key()][:timeout] || Runner.Transactions.timeout()

    update_transactions_options = %{timeout: transactions_timeout, timestamps: timestamps}

    # Enforce ShareLocks tables order (see docs: sharelocks.md)
    multi
    |> Multi.run(:acquire_transactions, fn repo, _ ->
      acquire_transactions(repo, changes_list)
    end)
    |> Multi.run(:internal_transactions, fn repo, %{acquire_transactions: transactions} ->
      insert(repo, changes_list_without_first_traces, transactions, insert_options)
    end)
    |> Multi.run(:internal_transactions_indexed_at_transactions, fn repo, %{acquire_transactions: transactions} ->
      update_transactions(repo, transactions, update_transactions_options)
    end)
    |> Multi.run(:set_first_trace_fields, fn repo, %{acquire_transactions: transactions} ->
      set_first_trace_fields(repo, transactions, first_traces)
    end)
    |> Multi.run(
      :remove_consensus_of_missing_transactions_blocks,
      fn repo, %{internal_transactions: inserted} = results_map ->
        # NOTE: for this to work it has to follow the runner `internal_transactions_indexed_at_blocks`
        block_hashes = Map.get(results_map, :internal_transactions_indexed_at_blocks, [])
        remove_consensus_of_missing_transactions_blocks(repo, block_hashes, changes_list, inserted)
      end
    )
  end

  @impl Runner
  def timeout, do: @timeout

  @spec insert(Repo.t(), [map], [Transaction.t()], %{
          optional(:on_conflict) => Runner.on_conflict(),
          required(:timeout) => timeout,
          required(:timestamps) => Import.timestamps()
        }) ::
          {:ok, [%{index: non_neg_integer, transaction_hash: Hash.t()}]}
          | {:error, [Changeset.t()]}
  defp insert(repo, changes_list, transactions, %{timeout: timeout, timestamps: timestamps} = options)
       when is_list(changes_list) do
    on_conflict = Map.get_lazy(options, :on_conflict, &default_on_conflict/0)

    transactions_map = Map.new(transactions, &{&1.hash, &1})

    final_changes_list =
      changes_list
      # Enforce InternalTransaction ShareLocks order (see docs: sharelocks.md)
      |> Enum.sort_by(&{&1.transaction_hash, &1.index})
      |> reject_missing_transactions(transactions_map)

    {:ok, internal_transactions} =
      Import.insert_changes_list(
        repo,
        final_changes_list,
        conflict_target: [:transaction_hash, :index],
        for: InternalTransaction,
        on_conflict: on_conflict,
        returning: true,
        timeout: timeout,
        timestamps: timestamps
      )

    {:ok, internal_transactions}
  end

  defp default_on_conflict do
    from(
      internal_transaction in InternalTransaction,
      update: [
        set: [
          block_number: fragment("EXCLUDED.block_number"),
          call_type: fragment("EXCLUDED.call_type"),
          created_contract_address_hash: fragment("EXCLUDED.created_contract_address_hash"),
          created_contract_code: fragment("EXCLUDED.created_contract_code"),
          error: fragment("EXCLUDED.error"),
          from_address_hash: fragment("EXCLUDED.from_address_hash"),
          gas: fragment("EXCLUDED.gas"),
          gas_used: fragment("EXCLUDED.gas_used"),
          # Don't update `index` as it is part of the composite primary key and used for the conflict target
          init: fragment("EXCLUDED.init"),
          input: fragment("EXCLUDED.input"),
          output: fragment("EXCLUDED.output"),
          to_address_hash: fragment("EXCLUDED.to_address_hash"),
          trace_address: fragment("EXCLUDED.trace_address"),
          # Don't update `transaction_hash` as it is part of the composite primary key and used for the conflict target
          transaction_index: fragment("EXCLUDED.transaction_index"),
          type: fragment("EXCLUDED.type"),
          value: fragment("EXCLUDED.value"),
          inserted_at: fragment("LEAST(?, EXCLUDED.inserted_at)", internal_transaction.inserted_at),
          updated_at: fragment("GREATEST(?, EXCLUDED.updated_at)", internal_transaction.updated_at)
        ]
      ],
      # `IS DISTINCT FROM` is used because it allows `NULL` to be equal to itself
      where:
        fragment(
          "(EXCLUDED.call_type, EXCLUDED.created_contract_address_hash, EXCLUDED.created_contract_code, EXCLUDED.error, EXCLUDED.from_address_hash, EXCLUDED.gas, EXCLUDED.gas_used, EXCLUDED.init, EXCLUDED.input, EXCLUDED.output, EXCLUDED.to_address_hash, EXCLUDED.trace_address, EXCLUDED.transaction_index, EXCLUDED.type, EXCLUDED.value) IS DISTINCT FROM (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
          internal_transaction.call_type,
          internal_transaction.created_contract_address_hash,
          internal_transaction.created_contract_code,
          internal_transaction.error,
          internal_transaction.from_address_hash,
          internal_transaction.gas,
          internal_transaction.gas_used,
          internal_transaction.init,
          internal_transaction.input,
          internal_transaction.output,
          internal_transaction.to_address_hash,
          internal_transaction.trace_address,
          internal_transaction.transaction_index,
          internal_transaction.type,
          internal_transaction.value
        )
    )
  end

  defp acquire_transactions(repo, internal_transactions) do
    transaction_hashes =
      internal_transactions
      |> MapSet.new(& &1.transaction_hash)
      |> MapSet.to_list()

    query =
      from(
        t in Transaction,
        where: t.hash in ^transaction_hashes,
        # do not consider pending transactions
        where: not is_nil(t.block_hash),
        select: map(t, [:hash, :block_hash, :block_number]),
        # Enforce Transaction ShareLocks order (see docs: sharelocks.md)
        order_by: t.hash,
        lock: "FOR UPDATE"
      )

    {:ok, repo.all(query)}
  end

  defp update_transactions(repo, transactions, %{
         timeout: timeout,
         timestamps: timestamps
       })
       when is_list(transactions) do
    transaction_hashes = Enum.map(transactions, & &1.hash)

    update_query =
      from(
        t in Transaction,
        # pending transactions are already excluded by `acquire_transactions`
        where: t.hash in ^transaction_hashes,
        # ShareLocks order already enforced by `acquire_transactions` (see docs: sharelocks.md)
        update: [
          set: [
            internal_transactions_indexed_at: ^timestamps.updated_at,
            created_contract_address_hash:
              fragment(
                "(SELECT it.created_contract_address_hash FROM internal_transactions AS it WHERE it.transaction_hash = ? ORDER BY it.index ASC LIMIT 1)",
                t.hash
              ),
            error:
              fragment(
                "(SELECT it.error FROM internal_transactions AS it WHERE it.transaction_hash = ? ORDER BY it.index ASC LIMIT 1)",
                t.hash
              ),
            status:
              fragment(
                "CASE WHEN (SELECT it.error FROM internal_transactions AS it WHERE it.transaction_hash = ? ORDER BY it.index ASC LIMIT 1) IS NULL THEN ? ELSE ? END",
                t.hash,
                type(^:ok, t.status),
                type(^:error, t.status)
              )
          ]
        ]
      )

    try do
      {_transaction_count, result} = repo.update_all(update_query, [], timeout: timeout)

      {:ok, result}
    rescue
      postgrex_error in Postgrex.Error ->
        {:error, %{exception: postgrex_error, transaction_hashes: transaction_hashes}}
    end
  end

  defp set_first_trace_fields(repo, transactions, first_traces) do
    params =
      Enum.map(first_traces, fn first_trace ->
        %{
          first_trace_gas_used: first_trace.gas_used,
          first_trace_output: first_trace.output,
          hash: first_trace.transaction_hash
        }
      end)

    valid_params =
      transactions
      |> Enum.map(fn transaction ->
        found_params =
          Enum.find(params, fn param ->
            param.hash == transaction.hash
          end)

        {transaction, found_params}
      end)
      |> Enum.reject(fn {tx, params} -> is_nil(params) || is_nil(tx.block_hash) end)
      |> Enum.map(fn {_tx, params} -> params end)

    try do
      {_transaction_count, result} =
        repo.insert_all(Transaction, valid_params,
          on_conflict: {:replace, [:first_trace_gas_used, :first_trace_output]},
          conflict_target: :hash
        )

      {:ok, result}
    rescue
      postgrex_error in Postgrex.Error ->
        {:error, %{exception: postgrex_error, first_traces: first_traces}}
    end
  end

  # If not using Parity this is not relevant
  defp remove_consensus_of_missing_transactions_blocks(_, [], _, _), do: {:ok, []}

  defp remove_consensus_of_missing_transactions_blocks(repo, block_hashes, changes_list, inserted) do
    inserted_block_numbers = MapSet.new(inserted, & &1.block_number)

    missing_transactions_block_numbers =
      changes_list
      |> MapSet.new(& &1.block_number)
      |> MapSet.difference(inserted_block_numbers)
      |> MapSet.to_list()

    update_query =
      from(
        b in Block,
        where: b.number in ^missing_transactions_block_numbers,
        where: b.hash in ^block_hashes,
        select: b.number,
        # ShareLocks order already enforced by `internal_transactions_indexed_at_blocks` (see docs: sharelocks.md)
        update: [set: [consensus: false, internal_transactions_indexed_at: nil]]
      )

    try do
      {_num, result} = repo.update_all(update_query, [])

      Logger.debug(fn ->
        [
          "consensus removed from blocks with numbers: ",
          inspect(missing_transactions_block_numbers),
          " because of missing transactions"
        ]
      end)

      {:ok, result}
    rescue
      postgrex_error in Postgrex.Error ->
        {:error, %{exception: postgrex_error, missing_transactions_block_numbers: missing_transactions_block_numbers}}
    end
  end

  defp reject_missing_transactions(ordered_changes_list, transactions_map) do
    Enum.reject(ordered_changes_list, fn %{transaction_hash: hash} ->
      transactions_map
      |> Map.get(hash, %{})
      |> Map.get(:block_hash)
      |> is_nil()
    end)
  end
end
