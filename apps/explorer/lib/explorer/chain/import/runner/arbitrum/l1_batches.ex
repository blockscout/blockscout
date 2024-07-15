defmodule Explorer.Chain.Import.Runner.Arbitrum.L1Batches do
  @moduledoc """
    Bulk imports of Explorer.Chain.Arbitrum.L1Batch.
  """

  require Ecto.Query

  alias Ecto.{Changeset, Multi, Repo}
  alias Explorer.Chain.Arbitrum.L1Batch
  alias Explorer.Chain.Import
  alias Explorer.Prometheus.Instrumenter

  import Ecto.Query, only: [from: 2]

  @behaviour Import.Runner

  # milliseconds
  @timeout 60_000

  @type imported :: [L1Batch.t()]

  @impl Import.Runner
  def ecto_schema_module, do: L1Batch

  @impl Import.Runner
  def option_key, do: :arbitrum_l1_batches

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

    Multi.run(multi, :insert_arbitrum_l1_batches, fn repo, _ ->
      Instrumenter.block_import_stage_runner(
        fn -> insert(repo, changes_list, insert_options) end,
        :block_referencing,
        :arbitrum_l1_batches,
        :arbitrum_l1_batches
      )
    end)
  end

  @impl Import.Runner
  def timeout, do: @timeout

  @spec insert(Repo.t(), [map()], %{required(:timeout) => timeout(), required(:timestamps) => Import.timestamps()}) ::
          {:ok, [L1Batch.t()]}
          | {:error, [Changeset.t()]}
  def insert(repo, changes_list, %{timeout: timeout, timestamps: timestamps} = options) when is_list(changes_list) do
    on_conflict = Map.get_lazy(options, :on_conflict, &default_on_conflict/0)

    # Enforce Arbitrum.L1Batch ShareLocks order (see docs: sharelock.md)
    ordered_changes_list = Enum.sort_by(changes_list, & &1.number)

    {:ok, inserted} =
      Import.insert_changes_list(
        repo,
        ordered_changes_list,
        for: L1Batch,
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
      tb in L1Batch,
      update: [
        set: [
          # don't update `number` as it is a primary key and used for the conflict target
          transactions_count: fragment("EXCLUDED.transactions_count"),
          start_block: fragment("EXCLUDED.start_block"),
          end_block: fragment("EXCLUDED.end_block"),
          before_acc: fragment("EXCLUDED.before_acc"),
          after_acc: fragment("EXCLUDED.after_acc"),
          commitment_id: fragment("EXCLUDED.commitment_id"),
          batch_container: fragment("EXCLUDED.batch_container"),
          inserted_at: fragment("LEAST(?, EXCLUDED.inserted_at)", tb.inserted_at),
          updated_at: fragment("GREATEST(?, EXCLUDED.updated_at)", tb.updated_at)
        ]
      ],
      where:
        fragment(
          "(EXCLUDED.transactions_count, EXCLUDED.start_block, EXCLUDED.end_block, EXCLUDED.before_acc, EXCLUDED.after_acc, EXCLUDED.commitment_id, EXCLUDED.batch_container) IS DISTINCT FROM (?, ?, ?, ?, ?, ?, ?)",
          tb.transactions_count,
          tb.start_block,
          tb.end_block,
          tb.before_acc,
          tb.after_acc,
          tb.commitment_id,
          tb.batch_container
        )
    )
  end
end
