defmodule Explorer.Chain.Import.Runner.ZkevmTxnBatches do
  @moduledoc """
  Bulk imports `t:Explorer.Chain.ZkevmTxnBatch.t/0`.
  """

  require Ecto.Query

  alias Ecto.{Changeset, Multi, Repo}
  alias Explorer.Chain.{Import, ZkevmTxnBatch}
  alias Explorer.Prometheus.Instrumenter

  import Ecto.Query, only: [from: 2]

  @behaviour Import.Runner

  # milliseconds
  @timeout 60_000

  @type imported :: [ZkevmTxnBatch.t()]

  @impl Import.Runner
  def ecto_schema_module, do: ZkevmTxnBatch

  @impl Import.Runner
  def option_key, do: :zkevm_txn_batches

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

    Multi.run(multi, :insert_zkevm_txn_batches, fn repo, _ ->
      Instrumenter.block_import_stage_runner(
        fn -> insert(repo, changes_list, insert_options) end,
        :block_referencing,
        :zkevm_txn_batches,
        :zkevm_txn_batches
      )
    end)
  end

  @impl Import.Runner
  def timeout, do: @timeout

  @spec insert(Repo.t(), [map()], %{required(:timeout) => timeout(), required(:timestamps) => Import.timestamps()}) ::
          {:ok, [ZkevmTxnBatch.t()]}
          | {:error, [Changeset.t()]}
  def insert(repo, changes_list, %{timeout: timeout, timestamps: timestamps} = options) when is_list(changes_list) do
    on_conflict = Map.get_lazy(options, :on_conflict, &default_on_conflict/0)

    # Enforce ZkevmTxnBatch ShareLocks order (see docs: sharelock.md)
    ordered_changes_list = Enum.sort_by(changes_list, & &1.number)

    {:ok, inserted} =
      Import.insert_changes_list(
        repo,
        ordered_changes_list,
        for: ZkevmTxnBatch,
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
      tb in ZkevmTxnBatch,
      update: [
        set: [
          # don't update `number` as it is a primary key and used for the conflict target
          timestamp: fragment("EXCLUDED.timestamp"),
          l2_transactions_count: fragment("EXCLUDED.l2_transactions_count"),
          global_exit_root: fragment("EXCLUDED.global_exit_root"),
          acc_input_hash: fragment("EXCLUDED.acc_input_hash"),
          state_root: fragment("EXCLUDED.state_root"),
          sequence_id: fragment("EXCLUDED.sequence_id"),
          verify_id: fragment("EXCLUDED.verify_id"),
          inserted_at: fragment("LEAST(?, EXCLUDED.inserted_at)", tb.inserted_at),
          updated_at: fragment("GREATEST(?, EXCLUDED.updated_at)", tb.updated_at)
        ]
      ],
      where:
        fragment(
          "(EXCLUDED.timestamp, EXCLUDED.l2_transactions_count, EXCLUDED.global_exit_root, EXCLUDED.acc_input_hash, EXCLUDED.state_root, EXCLUDED.sequence_id, EXCLUDED.verify_id) IS DISTINCT FROM (?, ?, ?, ?, ?, ?, ?)",
          tb.timestamp,
          tb.l2_transactions_count,
          tb.global_exit_root,
          tb.acc_input_hash,
          tb.state_root,
          tb.sequence_id,
          tb.verify_id
        )
    )
  end
end
