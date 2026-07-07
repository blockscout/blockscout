# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Migrator.FillLogsCompressedData do
  @moduledoc """
  Fills `compressed_data` and empties `data` fields in `logs` table.
  """

  use Explorer.Migrator.FillingMigration

  use Utils.RuntimeEnvHelper,
    chain_identity: [:explorer, :chain_identity]

  import Ecto.Query

  alias Explorer.Chain.Log
  alias Explorer.Migrator.{FillingMigration, FillLogsOptimizedFields}
  alias Explorer.Repo
  alias Explorer.Utility.LogHelper

  @migration_name "fill_logs_compressed_data"

  @impl FillingMigration
  def migration_name, do: @migration_name

  @impl FillingMigration
  def dependent_from_migrations,
    do: [FillLogsOptimizedFields.migration_name()]

  @impl FillingMigration
  def last_unprocessed_identifiers(state) do
    limit = batch_size() * concurrency()

    logs =
      unprocessed_data_query()
      |> limit(^limit)
      |> Repo.all(timeout: :infinity)

    max_block_number =
      case List.last(logs) do
        nil -> -1
        %{block_number: block_number} -> block_number
      end

    {logs, Map.put(state, "max_block_number", max_block_number)}
  end

  @impl FillingMigration
  def unprocessed_data_query do
    from(l in Log, where: not is_nil(l.data), order_by: [desc: l.block_number])
  end

  @impl FillingMigration
  def update_batch(logs) do
    params =
      Enum.map(logs, fn log ->
        log
        |> Map.from_struct()
        |> Map.drop([:block, :address, :transaction, :__meta__, :address_by_hash, :address_mapping, :log_first_topic])
        |> Map.merge(%{data: nil, compressed_data: log.data})
      end)

    {ordered_params, conflict_target} =
      case chain_identity() do
        {:optimism, :celo} ->
          if LogHelper.primary_key_updated?() do
            {
              Enum.sort_by(params, &{&1.block_number, &1.index}),
              [:index, :block_number]
            }
          else
            {
              Enum.sort_by(params, &{&1.block_number, &1.index}),
              [:index, :block_hash]
            }
          end

        _ ->
          if LogHelper.primary_key_updated?() do
            {
              Enum.sort_by(params, &{&1.block_number, &1.transaction_index, &1.index}),
              [:transaction_index, :index, :block_number]
            }
          else
            {
              Enum.sort_by(params, &{&1.block_number, &1.transaction_index, &1.index}),
              [:transaction_hash, :index, :block_hash]
            }
          end
      end

    {count, _} =
      Repo.safe_insert_all(Log, ordered_params,
        on_conflict: {:replace, [:data, :compressed_data]},
        conflict_target: conflict_target
      )

    count
  end

  @impl FillingMigration
  def update_cache, do: :ok
end
