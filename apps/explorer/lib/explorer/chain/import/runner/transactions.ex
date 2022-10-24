defmodule Explorer.Chain.Import.Runner.Transactions do
  @moduledoc """
  Bulk imports `t:Explorer.Chain.Transaction.t/0`.
  """

  require Ecto.Query

  import Ecto.Query, only: [from: 2]

  alias Ecto.{Multi, Repo}
  alias Explorer.Chain.{Block, Hash, Import, Transaction}
  alias Explorer.Chain.Import.Runner.TokenTransfers
  alias Explorer.Prometheus.Instrumenter

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

    # Enforce ShareLocks tables order (see docs: sharelocks.md)
    multi
    |> Multi.run(:recollated_transactions, fn repo, _ ->
      Instrumenter.block_import_stage_runner(
        fn ->
          discard_blocks_for_recollated_transactions(repo, changes_list, insert_options)
        end,
        :block_referencing,
        :transactions,
        :recollated_transactions
      )
    end)
    |> Multi.run(:transactions, fn repo, _ ->
      Instrumenter.block_import_stage_runner(
        fn -> insert(repo, changes_list, insert_options) end,
        :block_referencing,
        :transactions,
        :transactions
      )
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
           timestamps: timestamps
         } = options
       )
       when is_list(changes_list) do
    on_conflict = Map.get_lazy(options, :on_conflict, &default_on_conflict/0)

    # Enforce Transaction ShareLocks order (see docs: sharelocks.md)
    ordered_changes_list = Enum.sort_by(changes_list, & &1.hash)

    Import.insert_changes_list(
      repo,
      ordered_changes_list,
      conflict_target: :hash,
      on_conflict: on_conflict,
      for: Transaction,
      returning: true,
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
          old_block_hash: transaction.block_hash,
          block_number: fragment("EXCLUDED.block_number"),
          block_consensus: fragment("EXCLUDED.block_consensus"),
          block_timestamp: fragment("EXCLUDED.block_timestamp"),
          created_contract_address_hash: fragment("EXCLUDED.created_contract_address_hash"),
          created_contract_code_indexed_at: fragment("EXCLUDED.created_contract_code_indexed_at"),
          cumulative_gas_used: fragment("EXCLUDED.cumulative_gas_used"),
          error: fragment("EXCLUDED.error"),
          from_address_hash: fragment("EXCLUDED.from_address_hash"),
          gas: fragment("EXCLUDED.gas"),
          gas_price: fragment("EXCLUDED.gas_price"),
          gas_used: fragment("EXCLUDED.gas_used"),
          index: fragment("EXCLUDED.index"),
          input: fragment("EXCLUDED.input"),
          nonce: fragment("EXCLUDED.nonce"),
          r: fragment("EXCLUDED.r"),
          s: fragment("EXCLUDED.s"),
          status: fragment("EXCLUDED.status"),
          to_address_hash: fragment("EXCLUDED.to_address_hash"),
          v: fragment("EXCLUDED.v"),
          value: fragment("EXCLUDED.value"),
          earliest_processing_start: fragment("EXCLUDED.earliest_processing_start"),
          revert_reason: fragment("EXCLUDED.revert_reason"),
          max_priority_fee_per_gas: fragment("EXCLUDED.max_priority_fee_per_gas"),
          max_fee_per_gas: fragment("EXCLUDED.max_fee_per_gas"),
          type: fragment("EXCLUDED.type"),
          # Don't update `hash` as it is part of the primary key and used for the conflict target
          inserted_at: fragment("LEAST(?, EXCLUDED.inserted_at)", transaction.inserted_at),
          updated_at: fragment("GREATEST(?, EXCLUDED.updated_at)", transaction.updated_at)
        ]
      ],
      where:
        fragment(
          "(EXCLUDED.block_hash, EXCLUDED.block_number, EXCLUDED.block_consensus, EXCLUDED.block_timestamp, EXCLUDED.created_contract_address_hash, EXCLUDED.created_contract_code_indexed_at, EXCLUDED.cumulative_gas_used, EXCLUDED.from_address_hash, EXCLUDED.gas, EXCLUDED.gas_price, EXCLUDED.gas_used, EXCLUDED.index, EXCLUDED.input, EXCLUDED.nonce, EXCLUDED.r, EXCLUDED.s, EXCLUDED.status, EXCLUDED.to_address_hash, EXCLUDED.v, EXCLUDED.value, EXCLUDED.earliest_processing_start, EXCLUDED.revert_reason, EXCLUDED.max_priority_fee_per_gas, EXCLUDED.max_fee_per_gas, EXCLUDED.type) IS DISTINCT FROM (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
          transaction.block_hash,
          transaction.block_number,
          transaction.block_consensus,
          transaction.block_timestamp,
          transaction.created_contract_address_hash,
          transaction.created_contract_code_indexed_at,
          transaction.cumulative_gas_used,
          transaction.from_address_hash,
          transaction.gas,
          transaction.gas_price,
          transaction.gas_used,
          transaction.index,
          transaction.input,
          transaction.nonce,
          transaction.r,
          transaction.s,
          transaction.status,
          transaction.to_address_hash,
          transaction.v,
          transaction.value,
          transaction.earliest_processing_start,
          transaction.revert_reason,
          transaction.max_priority_fee_per_gas,
          transaction.max_fee_per_gas,
          transaction.type
        )
    )
  end

  defp discard_blocks_for_recollated_transactions(repo, changes_list, %{
         timeout: timeout,
         timestamps: %{updated_at: updated_at}
       })
       when is_list(changes_list) do
    {transactions_hashes, transactions_block_hashes} =
      changes_list
      |> Enum.filter(&Map.has_key?(&1, :block_hash))
      |> Enum.map(fn %{hash: hash, block_hash: block_hash} ->
        {:ok, hash_bytes} = Hash.Full.dump(hash)
        {:ok, block_hash_bytes} = Hash.Full.dump(block_hash)
        {hash_bytes, block_hash_bytes}
      end)
      |> Enum.unzip()

    blocks_with_recollated_transactions =
      from(
        transaction in Transaction,
        join:
          new_transaction in fragment(
            "(SELECT unnest(?::bytea[]) as hash, unnest(?::bytea[]) as block_hash)",
            ^transactions_hashes,
            ^transactions_block_hashes
          ),
        on: transaction.hash == new_transaction.hash,
        where: transaction.block_hash != new_transaction.block_hash,
        select: %{hash: transaction.hash, block_hash: transaction.block_hash}
      )

    block_hashes =
      blocks_with_recollated_transactions
      |> repo.all()
      |> Enum.map(fn %{block_hash: block_hash} -> block_hash end)
      |> Enum.uniq()

    transaction_hashes =
      blocks_with_recollated_transactions
      |> repo.all()
      |> Enum.map(fn %{hash: hash} -> hash end)

    if Enum.empty?(block_hashes) do
      {:ok, []}
    else
      query =
        from(
          block in Block,
          where: block.hash in ^block_hashes,
          # Enforce Block ShareLocks order (see docs: sharelocks.md)
          order_by: [asc: block.hash],
          lock: "FOR UPDATE"
        )

      try do
        {_, result} =
          repo.update_all(
            from(b in Block, join: s in subquery(query), on: b.hash == s.hash),
            [set: [consensus: false, updated_at: updated_at]],
            timeout: timeout
          )

        {:ok, result}
      rescue
        postgrex_error in Postgrex.Error ->
          {:error, %{exception: postgrex_error, block_hashes: block_hashes}}
      end
    end

    if Enum.empty?(transaction_hashes) do
      {:ok, []}
    else
      query =
        from(
          transaction in Transaction,
          where: transaction.hash in ^transaction_hashes,
          # Enforce Block ShareLocks order (see docs: sharelocks.md)
          order_by: [asc: transaction.hash],
          lock: "FOR UPDATE"
        )

      try do
        {_, result} =
          repo.update_all(
            from(transaction in Transaction, join: s in subquery(query), on: transaction.hash == s.hash),
            [set: [block_consensus: false, updated_at: updated_at]],
            timeout: timeout
          )

        {:ok, result}
      rescue
        postgrex_error in Postgrex.Error ->
          {:error, %{exception: postgrex_error, transaction_hashes: transaction_hashes}}
      end
    end
  end
end
