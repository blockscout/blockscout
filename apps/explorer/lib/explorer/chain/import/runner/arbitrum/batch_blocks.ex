defmodule Explorer.Chain.Import.Runner.Arbitrum.BatchBlocks do
  @moduledoc """
    Bulk imports of Explorer.Chain.Arbitrum.BatchBlock.
  """

  require Ecto.Query

  alias Ecto.{Changeset, Multi, Repo}
  alias Explorer.Chain.Arbitrum.BatchBlock
  alias Explorer.Chain.Import
  alias Explorer.Prometheus.Instrumenter

  import Ecto.Query, only: [from: 2]

  @behaviour Import.Runner

  # milliseconds
  @timeout 60_000

  @type imported :: [BatchBlock.t()]

  @impl Import.Runner
  def ecto_schema_module, do: BatchBlock

  @impl Import.Runner
  def option_key, do: :arbitrum_batch_blocks

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

    Multi.run(multi, :insert_arbitrum_batch_blocks, fn repo, _ ->
      Instrumenter.block_import_stage_runner(
        fn -> insert(repo, changes_list, insert_options) end,
        :block_referencing,
        :arbitrum_batch_blocks,
        :arbitrum_batch_blocks
      )
    end)
  end

  @impl Import.Runner
  def timeout, do: @timeout

  @spec insert(Repo.t(), [map()], %{required(:timeout) => timeout(), required(:timestamps) => Import.timestamps()}) ::
          {:ok, [BatchBlock.t()]}
          | {:error, [Changeset.t()]}
  def insert(repo, changes_list, %{timeout: timeout, timestamps: timestamps} = options) when is_list(changes_list) do
    on_conflict = Map.get_lazy(options, :on_conflict, &default_on_conflict/0)

    # Enforce Arbitrum.BatchBlock ShareLocks order (see docs: sharelock.md)
    ordered_changes_list = Enum.sort_by(changes_list, & &1.block_number)

    {:ok, inserted} =
      Import.insert_changes_list(
        repo,
        ordered_changes_list,
        for: BatchBlock,
        returning: true,
        timeout: timeout,
        timestamps: timestamps,
        conflict_target: :block_number,
        on_conflict: on_conflict
      )

    {:ok, inserted}
  end

  defp default_on_conflict do
    from(
      tb in BatchBlock,
      update: [
        set: [
          # don't update `block_number` as it is a primary key and used for the conflict target
          batch_number: fragment("EXCLUDED.batch_number"),
          confirmation_id: fragment("EXCLUDED.confirmation_id"),
          inserted_at: fragment("LEAST(?, EXCLUDED.inserted_at)", tb.inserted_at),
          updated_at: fragment("GREATEST(?, EXCLUDED.updated_at)", tb.updated_at)
        ]
      ],
      where:
        fragment(
          "(EXCLUDED.batch_number, EXCLUDED.confirmation_id) IS DISTINCT FROM (?, ?)",
          tb.batch_number,
          tb.confirmation_id
        )
    )
  end
end
