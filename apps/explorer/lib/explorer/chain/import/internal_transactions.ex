defmodule Explorer.Chain.Import.InternalTransactions do
  @moduledoc """
  Bulk imports `t:Explorer.Chain.InternalTransactions.t/0`.
  """

  require Ecto.Query

  alias Ecto.{Changeset, Multi}
  alias Explorer.Chain.{Hash, Import, InternalTransaction, Transaction}
  alias Explorer.Repo

  import Ecto.Query, only: [from: 2]

  # milliseconds
  @timeout 60_000

  @type options :: %{
          required(:params) => Import.params(),
          optional(:timeout) => timeout
        }
  @type imported :: [
          %{required(:index) => non_neg_integer(), required(:transaction_hash) => Hash.Full.t()}
        ]

  def run(multi, ecto_schema_module_to_changes_list_map, options)
      when is_map(ecto_schema_module_to_changes_list_map) and is_map(options) do
    case ecto_schema_module_to_changes_list_map do
      %{InternalTransaction => internal_transactions_changes} ->
        timestamps = Map.fetch!(options, :timestamps)

        multi
        |> Multi.run(:internal_transactions, fn _ ->
          insert(
            internal_transactions_changes,
            %{
              timeout: options[:internal_transactions][:timeout] || @timeout,
              timestamps: timestamps
            }
          )
        end)
        |> Multi.run(:internal_transactions_indexed_at_transactions, fn %{internal_transactions: internal_transactions}
                                                                        when is_list(internal_transactions) ->
          update_transactions(
            internal_transactions,
            %{
              timeout: options[:transactions][:timeout] || Import.Transactions.timeout(),
              timestamps: timestamps
            }
          )
        end)

      _ ->
        multi
    end
  end

  def timeout, do: @timeout

  @spec insert([map], %{required(:timeout) => timeout, required(:timestamps) => Import.timestamps()}) ::
          {:ok, [%{index: non_neg_integer, transaction_hash: Hash.t()}]}
          | {:error, [Changeset.t()]}
  defp insert(changes_list, %{timeout: timeout, timestamps: timestamps})
       when is_list(changes_list) do
    # order so that row ShareLocks are grabbed in a consistent order
    ordered_changes_list = Enum.sort_by(changes_list, &{&1.transaction_hash, &1.index})

    {:ok, internal_transactions} =
      Import.insert_changes_list(
        ordered_changes_list,
        conflict_target: [:transaction_hash, :index],
        for: InternalTransaction,
        on_conflict: :replace_all,
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
                "(SELECT it.created_contract_address_hash FROM internal_transactions AS it WHERE it.transaction_hash = ? and it.type = 'create' and ? IS NULL)",
                t.hash,
                t.to_address_hash
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
