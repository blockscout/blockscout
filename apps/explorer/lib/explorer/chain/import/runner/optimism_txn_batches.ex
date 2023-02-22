defmodule Explorer.Chain.Import.Runner.OptimismTxnBatches do
  @moduledoc """
  Bulk imports `t:Explorer.Chain.OptimismTxnBatch.t/0`.
  """

  require Ecto.Query

  alias Ecto.{Changeset, Multi, Repo}
  alias Explorer.Chain.{Import, OptimismTxnBatch}
  alias Explorer.Prometheus.Instrumenter

  import Ecto.Query, only: [from: 2]

  @behaviour Import.Runner

  # milliseconds
  @timeout 60_000

  @type imported :: [OptimismTxnBatch.t()]

  @impl Import.Runner
  def ecto_schema_module, do: OptimismTxnBatch

  @impl Import.Runner
  def option_key, do: :optimism_txn_batches

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

    Multi.run(multi, :insert_txn_batches, fn repo, _ ->
      Instrumenter.block_import_stage_runner(
        fn -> insert(repo, changes_list, insert_options) end,
        :block_referencing,
        :optimism_txn_batches,
        :optimism_txn_batches
      )
    end)
  end

  @impl Import.Runner
  def timeout, do: @timeout

  @spec insert(Repo.t(), [map()], %{required(:timeout) => timeout(), required(:timestamps) => Import.timestamps()}) ::
          {:ok, [OptimismTxnBatch.t()]}
          | {:error, [Changeset.t()]}
  def insert(repo, changes_list, %{timeout: timeout, timestamps: timestamps} = options) when is_list(changes_list) do
    on_conflict = Map.get_lazy(options, :on_conflict, &default_on_conflict/0)

    # Enforce OptimismTxnBatch ShareLocks order (see docs: sharelock.md)
    ordered_changes_list = Enum.sort_by(changes_list, & &1.l2_block_number)

    {:ok, inserted} =
      Import.insert_changes_list(
        repo,
        ordered_changes_list,
        for: OptimismTxnBatch,
        returning: true,
        timeout: timeout,
        timestamps: timestamps,
        conflict_target: :l2_block_number,
        on_conflict: on_conflict
      )

    {:ok, inserted}
  end

  defp default_on_conflict do
    from(
      tb in OptimismTxnBatch,
      update: [
        set: [
          # don't update `l2_block_number` as it is a primary key and used for the conflict target
          epoch_number: fragment("EXCLUDED.epoch_number"),
          l1_tx_hashes: fragment("EXCLUDED.l1_tx_hashes"),
          l1_tx_timestamp: fragment("EXCLUDED.l1_tx_timestamp"),
          inserted_at: fragment("LEAST(?, EXCLUDED.inserted_at)", tb.inserted_at),
          updated_at: fragment("GREATEST(?, EXCLUDED.updated_at)", tb.updated_at)
        ]
      ],
      where:
        fragment(
          "(EXCLUDED.epoch_number, EXCLUDED.l1_tx_hashes, EXCLUDED.l1_tx_timestamp) IS DISTINCT FROM (?, ?, ?)",
          tb.epoch_number,
          tb.l1_tx_hashes,
          tb.l1_tx_timestamp
        )
    )
  end
end
