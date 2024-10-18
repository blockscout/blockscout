defmodule Explorer.Chain.Import.Runner.ZkSync.TransactionBatches do
  @moduledoc """
  Bulk imports `t:Explorer.Chain.ZkSync.TransactionBatch.t/0`.
  """

  require Ecto.Query

  alias Ecto.{Changeset, Multi, Repo}
  alias Explorer.Chain.Import
  alias Explorer.Chain.ZkSync.TransactionBatch
  alias Explorer.Prometheus.Instrumenter

  import Ecto.Query, only: [from: 2]

  @behaviour Import.Runner

  # milliseconds
  @timeout 60_000

  @type imported :: [TransactionBatch.t()]

  @impl Import.Runner
  def ecto_schema_module, do: TransactionBatch

  @impl Import.Runner
  def option_key, do: :zksync_transaction_batches

  @impl Import.Runner
  @spec imported_table_row() :: %{:value_description => binary(), :value_type => binary()}
  def imported_table_row do
    %{
      value_type: "[#{ecto_schema_module()}.t()]",
      value_description: "List of `t:#{ecto_schema_module()}.t/0`s"
    }
  end

  @impl Import.Runner
  @spec run(Multi.t(), list(), map()) :: Multi.t()
  def run(multi, changes_list, %{timestamps: timestamps} = options) do
    insert_options =
      options
      |> Map.get(option_key(), %{})
      |> Map.take(~w(on_conflict timeout)a)
      |> Map.put_new(:timeout, @timeout)
      |> Map.put(:timestamps, timestamps)

    Multi.run(multi, :insert_zksync_transaction_batches, fn repo, _ ->
      Instrumenter.block_import_stage_runner(
        fn -> insert(repo, changes_list, insert_options) end,
        :block_referencing,
        :zksync_transaction_batches,
        :zksync_transaction_batches
      )
    end)
  end

  @impl Import.Runner
  def timeout, do: @timeout

  @spec insert(Repo.t(), [map()], %{required(:timeout) => timeout(), required(:timestamps) => Import.timestamps()}) ::
          {:ok, [TransactionBatch.t()]}
          | {:error, [Changeset.t()]}
  def insert(repo, changes_list, %{timeout: timeout, timestamps: timestamps} = options) when is_list(changes_list) do
    on_conflict = Map.get_lazy(options, :on_conflict, &default_on_conflict/0)

    # Enforce ZkSync.TransactionBatch ShareLocks order (see docs: sharelock.md)
    ordered_changes_list = Enum.sort_by(changes_list, & &1.number)

    {:ok, inserted} =
      Import.insert_changes_list(
        repo,
        ordered_changes_list,
        for: TransactionBatch,
        returning: true,
        timeout: timeout,
        timestamps: timestamps,
        conflict_target: :number,
        on_conflict: on_conflict
      )

    {:ok, inserted}
  end

  defp default_on_conflict do
    from(
      tb in TransactionBatch,
      update: [
        set: [
          # don't update `number` as it is a primary key and used for the conflict target
          timestamp: fragment("EXCLUDED.timestamp"),
          l1_transaction_count: fragment("EXCLUDED.l1_transaction_count"),
          l2_transaction_count: fragment("EXCLUDED.l2_transaction_count"),
          root_hash: fragment("EXCLUDED.root_hash"),
          l1_gas_price: fragment("EXCLUDED.l1_gas_price"),
          l2_fair_gas_price: fragment("EXCLUDED.l2_fair_gas_price"),
          start_block: fragment("EXCLUDED.start_block"),
          end_block: fragment("EXCLUDED.end_block"),
          commit_id: fragment("EXCLUDED.commit_id"),
          prove_id: fragment("EXCLUDED.prove_id"),
          execute_id: fragment("EXCLUDED.execute_id"),
          inserted_at: fragment("LEAST(?, EXCLUDED.inserted_at)", tb.inserted_at),
          updated_at: fragment("GREATEST(?, EXCLUDED.updated_at)", tb.updated_at)
        ]
      ],
      where:
        fragment(
          "(EXCLUDED.timestamp, EXCLUDED.l1_transaction_count, EXCLUDED.l2_transaction_count, EXCLUDED.root_hash, EXCLUDED.l1_gas_price, EXCLUDED.l2_fair_gas_price, EXCLUDED.start_block, EXCLUDED.end_block, EXCLUDED.commit_id, EXCLUDED.prove_id, EXCLUDED.execute_id) IS DISTINCT FROM (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
          tb.timestamp,
          tb.l1_transaction_count,
          tb.l2_transaction_count,
          tb.root_hash,
          tb.l1_gas_price,
          tb.l2_fair_gas_price,
          tb.start_block,
          tb.end_block,
          tb.commit_id,
          tb.prove_id,
          tb.execute_id
        )
    )
  end
end
