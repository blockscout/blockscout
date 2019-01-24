defmodule Explorer.Chain.Import.Runner.Transactions do
  @moduledoc """
  Bulk imports `t:Explorer.Chain.Transaction.t/0`.
  """

  require Ecto.Query

  import Ecto.Query, only: [from: 2]

  alias Ecto.{Multi, Repo}
  alias Explorer.Chain.{Data, Hash, Import, Transaction}
  alias Explorer.Chain.Import.Runner.TokenTransfers

  @behaviour Import.Runner

  # milliseconds
  @timeout 60_000

  @type imported :: [Hash.Full.t()]

  @impl Import.Runner
  def ecto_schema_module, do: Transaction

  @impl Import.Runner
  def option_key, do: :transactions

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
      |> Map.put(:token_transfer_transaction_hash_set, token_transfer_transaction_hash_set(options))

    transactions_timeout = options[option_key()][:timeout] || timeout()

    update_transactions_options = %{timeout: transactions_timeout}

    multi
    |> Multi.run(:transactions, fn repo, _ ->
      insert(repo, changes_list, insert_options)
    end)
    |> Multi.run(:replaced_transactions, fn repo, %{transactions: transactions} ->
      update_replaced_transactions(repo, transactions, update_transactions_options)
    end)
  end

  @impl Import.Runner
  def timeout, do: @timeout

  defp token_transfer_transaction_hash_set(options) do
    token_transfers_params = options[TokenTransfers.option_key()][:params] || []

    MapSet.new(token_transfers_params, & &1.transaction_hash)
  end

  @spec insert(Repo.t(), [map()], %{
          optional(:on_conflict) => Import.Runner.on_conflict(),
          required(:timeout) => timeout,
          required(:timestamps) => Import.timestamps(),
          required(:token_transfer_transaction_hash_set) => MapSet.t()
        }) :: {:ok, [Hash.t()]}
  defp insert(
         repo,
         changes_list,
         %{
           timeout: timeout,
           timestamps: %{inserted_at: inserted_at} = timestamps,
           token_transfer_transaction_hash_set: token_transfer_transaction_hash_set
         } = options
       )
       when is_list(changes_list) do
    on_conflict = Map.get_lazy(options, :on_conflict, &default_on_conflict/0)

    ordered_changes_list =
      changes_list
      |> put_internal_transactions_indexed_at(inserted_at, token_transfer_transaction_hash_set)
      # order so that row ShareLocks are grabbed in a consistent order
      |> Enum.sort_by(& &1.hash)

    Import.insert_changes_list(
      repo,
      ordered_changes_list,
      conflict_target: :hash,
      on_conflict: on_conflict,
      for: Transaction,
      returning: ~w(block_number index hash internal_transactions_indexed_at)a,
      timeout: timeout,
      timestamps: timestamps
    )
  end

  defp default_on_conflict do
    from(
      transaction in Transaction,
      update: [
        set: [
          block_hash: fragment("EXCLUDED.block_hash"),
          block_number: fragment("EXCLUDED.block_number"),
          created_contract_address_hash: fragment("EXCLUDED.created_contract_address_hash"),
          cumulative_gas_used: fragment("EXCLUDED.cumulative_gas_used"),
          error: fragment("EXCLUDED.error"),
          from_address_hash: fragment("EXCLUDED.from_address_hash"),
          gas: fragment("EXCLUDED.gas"),
          gas_price: fragment("EXCLUDED.gas_price"),
          gas_used: fragment("EXCLUDED.gas_used"),
          index: fragment("EXCLUDED.index"),
          internal_transactions_indexed_at: fragment("EXCLUDED.internal_transactions_indexed_at"),
          input: fragment("EXCLUDED.input"),
          nonce: fragment("EXCLUDED.nonce"),
          r: fragment("EXCLUDED.r"),
          s: fragment("EXCLUDED.s"),
          status: fragment("EXCLUDED.status"),
          to_address_hash: fragment("EXCLUDED.to_address_hash"),
          v: fragment("EXCLUDED.v"),
          value: fragment("EXCLUDED.value"),
          # Don't update `hash` as it is part of the primary key and used for the conflict target
          inserted_at: fragment("LEAST(?, EXCLUDED.inserted_at)", transaction.inserted_at),
          updated_at: fragment("GREATEST(?, EXCLUDED.updated_at)", transaction.updated_at)
        ]
      ],
      where:
        fragment(
          "(EXCLUDED.block_hash, EXCLUDED.block_number, EXCLUDED.created_contract_address_hash, EXCLUDED.cumulative_gas_used, EXCLUDED.cumulative_gas_used, EXCLUDED.from_address_hash, EXCLUDED.gas, EXCLUDED.gas_price, EXCLUDED.gas_used, EXCLUDED.index, EXCLUDED.internal_transactions_indexed_at, EXCLUDED.input, EXCLUDED.nonce, EXCLUDED.r, EXCLUDED.s, EXCLUDED.status, EXCLUDED.to_address_hash, EXCLUDED.v, EXCLUDED.value) IS DISTINCT FROM (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
          transaction.block_hash,
          transaction.block_number,
          transaction.created_contract_address_hash,
          transaction.cumulative_gas_used,
          transaction.cumulative_gas_used,
          transaction.from_address_hash,
          transaction.gas,
          transaction.gas_price,
          transaction.gas_used,
          transaction.index,
          transaction.internal_transactions_indexed_at,
          transaction.input,
          transaction.nonce,
          transaction.r,
          transaction.s,
          transaction.status,
          transaction.to_address_hash,
          transaction.v,
          transaction.value
        )
    )
  end

  defp put_internal_transactions_indexed_at(changes_list, timestamp, token_transfer_transaction_hash_set)
       when is_list(changes_list) do
    Enum.map(changes_list, &put_internal_transactions_indexed_at(&1, timestamp, token_transfer_transaction_hash_set))
  end

  defp put_internal_transactions_indexed_at(%{hash: hash} = changes, timestamp, token_transfer_transaction_hash_set) do
    token_transfer? = to_string(hash) in token_transfer_transaction_hash_set

    if put_internal_transactions_indexed_at?(changes, token_transfer?) do
      Map.put(changes, :internal_transactions_indexed_at, timestamp)
    else
      changes
    end
  end

  # A post-Byzantium validated transaction will have a status and if it has no input, it is a value transfer only.
  # Internal transactions are only needed when status is `:error` to set `error`.
  defp put_internal_transactions_indexed_at?(%{status: :ok, input: %Data{bytes: <<>>}}, _), do: true

  # A post-Byzantium validated transaction will have a status and if it transfers tokens, the token transfer is in the
  # log and the internal transactions.
  # `created_contract_address_hash` must be `nil` because if a contract is created the internal transactions are needed
  # to get
  defp put_internal_transactions_indexed_at?(%{status: :ok} = changes, true) do
    case Map.fetch(changes, :created_contract_address_hash) do
      {:ok, created_contract_address_hash} when not is_nil(created_contract_address_hash) -> false
      :error -> true
    end
  end

  defp put_internal_transactions_indexed_at?(_, _), do: false

  defp update_replaced_transactions(repo, transactions, %{timeout: timeout}) do
    transactions
    |> Enum.filter(& &1.transaction.block_hash)
    |> Enum.map(fn transaction -> {transaction.nonce, transaction.from_address_hash} end)
    |> Enum.uniq()
    |> Enum.map(fn {nonce, from_address_hash} ->
      from(t in Transaction,
        where: t.nonce == ^nonce and t.from_address_hash == ^from_address_hash and is_nil(t.block_hash),
        update: [
          set: [status: ^:error, error: "dropped/replaced"]
        ]
      )
    end)
    |> Enum.map(fn query ->
      try do
        {_, result} = repo.update(query, [], timeout: timeout)

        {:ok, result}
      rescue
        postgrex_error in Postgrex.Error ->
          {:error, %{exception: postgrex_error, query: query}}
      end
    end)
  end
end
