defmodule Explorer.Chain.Import.Runner.Scroll.Batches do
  @moduledoc """
  Bulk imports `Explorer.Chain.Scroll.Batch`.
  """

  require Ecto.Query

  import Ecto.Query, only: [from: 2]

  alias Ecto.{Changeset, Multi, Repo}
  alias Explorer.Chain.Import
  alias Explorer.Chain.Scroll.Batch, as: ScrollBatch
  alias Explorer.Prometheus.Instrumenter

  @behaviour Import.Runner

  # milliseconds
  @timeout 60_000

  @type imported :: [ScrollBatch.t()]

  @impl Import.Runner
  def ecto_schema_module, do: ScrollBatch

  @impl Import.Runner
  def option_key, do: :scroll_batches

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

    Multi.run(multi, :insert_scroll_batches, fn repo, _ ->
      Instrumenter.block_import_stage_runner(
        fn -> insert(repo, changes_list, insert_options) end,
        :block_referencing,
        :scroll_batches,
        :scroll_batches
      )
    end)
  end

  @impl Import.Runner
  def timeout, do: @timeout

  @spec insert(Repo.t(), [map()], %{required(:timeout) => timeout(), required(:timestamps) => Import.timestamps()}) ::
          {:ok, [ScrollBatch.t()]}
          | {:error, [Changeset.t()]}
  def insert(repo, changes_list, %{timeout: timeout, timestamps: timestamps} = options) when is_list(changes_list) do
    on_conflict = Map.get_lazy(options, :on_conflict, &default_on_conflict/0)

    # Enforce ScrollBatch ShareLocks order (see docs: sharelock.md)
    ordered_changes_list = Enum.sort_by(changes_list, & &1.number)

    {:ok, inserted} =
      Import.insert_changes_list(
        repo,
        ordered_changes_list,
        conflict_target: :number,
        on_conflict: on_conflict,
        for: ScrollBatch,
        returning: true,
        timeout: timeout,
        timestamps: timestamps
      )

    {:ok, inserted}
  end

  defp default_on_conflict do
    from(
      sb in ScrollBatch,
      update: [
        set: [
          # Don't update `number` as it is a primary key and used for the conflict target
          number: fragment("EXCLUDED.number"),
          commit_transaction_hash: fragment("EXCLUDED.commit_transaction_hash"),
          commit_block_number: fragment("EXCLUDED.commit_block_number"),
          commit_timestamp: fragment("EXCLUDED.commit_timestamp"),
          l2_block_range: fragment("EXCLUDED.l2_block_range"),
          container: fragment("EXCLUDED.container"),
          inserted_at: fragment("LEAST(?, EXCLUDED.inserted_at)", sb.inserted_at),
          updated_at: fragment("GREATEST(?, EXCLUDED.updated_at)", sb.updated_at)
        ]
      ],
      where:
        fragment(
          "(EXCLUDED.number, EXCLUDED.commit_transaction_hash, EXCLUDED.commit_block_number, EXCLUDED.commit_timestamp, EXCLUDED.l2_block_range, EXCLUDED.container) IS DISTINCT FROM (?, ?, ?, ?, ?, ?)",
          sb.number,
          sb.commit_transaction_hash,
          sb.commit_block_number,
          sb.commit_timestamp,
          sb.l2_block_range,
          sb.container
        )
    )
  end
end
