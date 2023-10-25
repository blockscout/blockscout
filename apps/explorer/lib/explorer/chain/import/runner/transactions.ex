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
  alias Explorer.Utility.MissingRangesManipulator

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
    if System.get_env("CHAIN_TYPE") == "suave" do
      from(
        transaction in Transaction,
        update: [
          set: [
            block_hash: fragment("EXCLUDED.block_hash"),
            old_block_hash: transaction.block_hash,
            block_number: fragment("EXCLUDED.block_number"),
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
            execution_node_hash: fragment("EXCLUDED.execution_node_hash"),
            wrapped_type: fragment("EXCLUDED.wrapped_type"),
            wrapped_nonce: fragment("EXCLUDED.wrapped_nonce"),
            wrapped_to_address_hash: fragment("EXCLUDED.wrapped_to_address_hash"),
            wrapped_gas: fragment("EXCLUDED.wrapped_gas"),
            wrapped_gas_price: fragment("EXCLUDED.wrapped_gas_price"),
            wrapped_max_priority_fee_per_gas: fragment("EXCLUDED.wrapped_max_priority_fee_per_gas"),
            wrapped_max_fee_per_gas: fragment("EXCLUDED.wrapped_max_fee_per_gas"),
            wrapped_value: fragment("EXCLUDED.wrapped_value"),
            wrapped_input: fragment("EXCLUDED.wrapped_input"),
            wrapped_v: fragment("EXCLUDED.wrapped_v"),
            wrapped_r: fragment("EXCLUDED.wrapped_r"),
            wrapped_s: fragment("EXCLUDED.wrapped_s"),
            wrapped_hash: fragment("EXCLUDED.wrapped_hash"),
            # Don't update `hash` as it is part of the primary key and used for the conflict target
            inserted_at: fragment("LEAST(?, EXCLUDED.inserted_at)", transaction.inserted_at),
            updated_at: fragment("GREATEST(?, EXCLUDED.updated_at)", transaction.updated_at)
          ]
        ],
        where:
          fragment(
            "(EXCLUDED.block_hash, EXCLUDED.block_number, EXCLUDED.created_contract_address_hash, EXCLUDED.created_contract_code_indexed_at, EXCLUDED.cumulative_gas_used, EXCLUDED.from_address_hash, EXCLUDED.gas, EXCLUDED.gas_price, EXCLUDED.gas_used, EXCLUDED.index, EXCLUDED.input, EXCLUDED.nonce, EXCLUDED.r, EXCLUDED.s, EXCLUDED.status, EXCLUDED.to_address_hash, EXCLUDED.v, EXCLUDED.value, EXCLUDED.earliest_processing_start, EXCLUDED.revert_reason, EXCLUDED.max_priority_fee_per_gas, EXCLUDED.max_fee_per_gas, EXCLUDED.type, EXCLUDED.execution_node_hash, EXCLUDED.wrapped_type, EXCLUDED.wrapped_nonce, EXCLUDED.wrapped_to_address_hash, EXCLUDED.wrapped_gas, EXCLUDED.wrapped_gas_price, EXCLUDED.wrapped_max_priority_fee_per_gas, EXCLUDED.wrapped_max_fee_per_gas, EXCLUDED.wrapped_value, EXCLUDED.wrapped_input, EXCLUDED.wrapped_v, EXCLUDED.wrapped_r, EXCLUDED.wrapped_s, EXCLUDED.wrapped_hash) IS DISTINCT FROM (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
            transaction.block_hash,
            transaction.block_number,
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
            transaction.type,
            transaction.execution_node_hash,
            transaction.wrapped_type,
            transaction.wrapped_nonce,
            transaction.wrapped_to_address_hash,
            transaction.wrapped_gas,
            transaction.wrapped_gas_price,
            transaction.wrapped_max_priority_fee_per_gas,
            transaction.wrapped_max_fee_per_gas,
            transaction.wrapped_value,
            transaction.wrapped_input,
            transaction.wrapped_v,
            transaction.wrapped_r,
            transaction.wrapped_s,
            transaction.wrapped_hash
          )
      )
    else
      from(
        transaction in Transaction,
        update: [
          set: [
            block_hash: fragment("EXCLUDED.block_hash"),
            old_block_hash: transaction.block_hash,
            block_number: fragment("EXCLUDED.block_number"),
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
            "(EXCLUDED.block_hash, EXCLUDED.block_number, EXCLUDED.created_contract_address_hash, EXCLUDED.created_contract_code_indexed_at, EXCLUDED.cumulative_gas_used, EXCLUDED.from_address_hash, EXCLUDED.gas, EXCLUDED.gas_price, EXCLUDED.gas_used, EXCLUDED.index, EXCLUDED.input, EXCLUDED.nonce, EXCLUDED.r, EXCLUDED.s, EXCLUDED.status, EXCLUDED.to_address_hash, EXCLUDED.v, EXCLUDED.value, EXCLUDED.earliest_processing_start, EXCLUDED.revert_reason, EXCLUDED.max_priority_fee_per_gas, EXCLUDED.max_fee_per_gas, EXCLUDED.type) IS DISTINCT FROM (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
            transaction.block_hash,
            transaction.block_number,
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
        select: transaction.block_hash
      )

    block_hashes =
      blocks_with_recollated_transactions
      |> repo.all()
      |> Enum.uniq()

    if Enum.empty?(block_hashes) do
      {:ok, []}
    else
      query =
        from(
          block in Block,
          where: block.hash in ^block_hashes,
          # Enforce Block ShareLocks order (see docs: sharelocks.md)
          order_by: [asc: block.hash],
          lock: "FOR NO KEY UPDATE"
        )

      transactions_query =
        from(
          transaction in Transaction,
          where: transaction.block_hash in ^block_hashes,
          # Enforce Transaction ShareLocks order (see docs: sharelocks.md)
          order_by: [asc: :hash],
          lock: "FOR NO KEY UPDATE"
        )

      transactions_replacements = [
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
        updated_at: updated_at
      ]

      try do
        {_, result} =
          repo.update_all(
            from(b in Block, join: s in subquery(query), on: b.hash == s.hash, select: b.number),
            [set: [consensus: false, updated_at: updated_at]],
            timeout: timeout
          )

        {_, _transactions_result} =
          repo.update_all(
            from(t in Transaction, join: s in subquery(transactions_query), on: t.hash == s.hash),
            [set: transactions_replacements],
            timeout: timeout
          )

        MissingRangesManipulator.add_ranges_by_block_numbers(result)

        {:ok, result}
      rescue
        postgrex_error in Postgrex.Error ->
          {:error, %{exception: postgrex_error, block_hashes: block_hashes}}
      end
    end
  end
end
