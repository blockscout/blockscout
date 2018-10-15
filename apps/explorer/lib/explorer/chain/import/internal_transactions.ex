defmodule Explorer.Chain.Import.InternalTransactions do
  @moduledoc """
  Bulk imports `t:Explorer.Chain.InternalTransactions.t/0`.
  """

  require Ecto.Query

  alias Ecto.{Changeset, Multi}
  alias Explorer.Chain.{Hash, Import, InternalTransaction, Transaction}
  alias Explorer.Repo

  import Ecto.Query, only: [from: 2]

  @behaviour Import.Runner

  # milliseconds
  @timeout 60_000

  @type imported :: [
          %{required(:index) => non_neg_integer(), required(:transaction_hash) => Hash.Full.t()}
        ]

  @impl Import.Runner
  def ecto_schema_module, do: InternalTransaction

  @impl Import.Runner
  def option_key, do: :internal_transactions

  @impl Import.Runner
  def imported_table_row do
    %{
      value_type: "[%{index: non_neg_integer(), transaction_hash: Explorer.Chain.Hash.t()}]",
      value_description: "List of maps of the `t:Explorer.Chain.InternalTransaction.t/0` `index` and `transaction_hash`"
    }
  end

  @impl Import.Runner
  def run(multi, changes_list, options) when is_map(options) do
    timestamps = Map.fetch!(options, :timestamps)
    internal_transactions_timeout = options[option_key()][:timeout] || @timeout
    transactions_timeout = options[Import.Transactions.option_key()][:timeout] || Import.Transactions.timeout()

    multi
    |> Multi.run(:internal_transactions, fn _ ->
      insert(changes_list, %{timeout: internal_transactions_timeout, timestamps: timestamps})
    end)
    |> Multi.run(:internal_transactions_indexed_at_transactions, fn %{internal_transactions: internal_transactions}
                                                                    when is_list(internal_transactions) ->
      update_transactions(internal_transactions, %{timeout: transactions_timeout, timestamps: timestamps})
    end)
  end

  @impl Import.Runner
  def timeout, do: @timeout

  @spec insert([map], %{required(:timeout) => timeout, required(:timestamps) => Import.timestamps()}) ::
          {:ok, [%{index: non_neg_integer, transaction_hash: Hash.t()}]}
          | {:error, [Changeset.t()]}
  defp insert(changes_list, %{timeout: timeout, timestamps: timestamps} = options)
       when is_list(changes_list) do
    on_conflict = Map.get(options, :on_conflict, :replace_all)

    # order so that row ShareLocks are grabbed in a consistent order
    ordered_changes_list = Enum.sort_by(changes_list, &{&1.transaction_hash, &1.index})

    {:ok, internal_transactions} =
      Import.insert_changes_list(
        ordered_changes_list,
        conflict_target: [:transaction_hash, :index],
        for: InternalTransaction,
        on_conflict: on_conflict,
        returning: [:id, :index, :transaction_hash],
        timeout: timeout,
        timestamps: timestamps
      )

    {:ok,
     for(
       internal_transaction <- internal_transactions,
       do: Map.take(internal_transaction, [:id, :index, :transaction_hash])
     )}
  end

  defp update_transactions(internal_transactions, %{
         timeout: timeout,
         timestamps: timestamps
       })
       when is_list(internal_transactions) do
    ordered_transaction_hashes =
      internal_transactions
      |> MapSet.new(& &1.transaction_hash)
      |> Enum.sort()

    query =
      from(
        t in Transaction,
        where: t.hash in ^ordered_transaction_hashes,
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
                "COALESCE(?, CASE WHEN (SELECT it.error FROM internal_transactions AS it WHERE it.transaction_hash = ? ORDER BY it.index ASC LIMIT 1) IS NULL THEN ? ELSE ? END)",
                t.status,
                t.hash,
                type(^:ok, t.status),
                type(^:error, t.status)
              )
          ]
        ]
      )

    transaction_count = Enum.count(ordered_transaction_hashes)

    try do
      {^transaction_count, result} = Repo.update_all(query, [], timeout: timeout)

      {:ok, result}
    rescue
      postgrex_error in Postgrex.Error ->
        {:error, %{exception: postgrex_error, transaction_hashes: ordered_transaction_hashes}}
    end
  end
end
