defmodule Explorer.Chain.Import.Runner.OptimismOutputRoots do
  @moduledoc """
  Bulk imports `t:Explorer.Chain.OptimismOutputRoot.t/0`.
  """

  require Ecto.Query

  alias Ecto.{Changeset, Multi, Repo}
  alias Explorer.Chain.{Import, OptimismOutputRoot}
  alias Explorer.Prometheus.Instrumenter

  import Ecto.Query, only: [from: 2]

  @behaviour Import.Runner

  # milliseconds
  @timeout 60_000

  @type imported :: [OptimismOutputRoot.t()]

  @impl Import.Runner
  def ecto_schema_module, do: OptimismOutputRoot

  @impl Import.Runner
  def option_key, do: :optimism_output_roots

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

    Multi.run(multi, :insert_output_roots, fn repo, _ ->
      Instrumenter.block_import_stage_runner(
        fn -> insert(repo, changes_list, insert_options) end,
        :block_referencing,
        :optimism_output_roots,
        :optimism_output_roots
      )
    end)
  end

  @impl Import.Runner
  def timeout, do: @timeout

  @spec insert(Repo.t(), [map()], %{required(:timeout) => timeout(), required(:timestamps) => Import.timestamps()}) ::
          {:ok, [OptimismOutputRoot.t()]}
          | {:error, [Changeset.t()]}
  def insert(repo, changes_list, %{timeout: timeout, timestamps: timestamps} = options) when is_list(changes_list) do
    on_conflict = Map.get_lazy(options, :on_conflict, &default_on_conflict/0)

    # Enforce OptimismOutputRoot ShareLocks order (see docs: sharelock.md)
    ordered_changes_list = Enum.sort_by(changes_list, & &1.l2_output_index)

    {:ok, inserted} =
      Import.insert_changes_list(
        repo,
        ordered_changes_list,
        for: OptimismOutputRoot,
        returning: true,
        timeout: timeout,
        timestamps: timestamps,
        conflict_target: :l2_output_index,
        on_conflict: on_conflict
      )

    {:ok, inserted}
  end

  defp default_on_conflict do
    from(
      root in OptimismOutputRoot,
      update: [
        set: [
          # don't update `l2_output_index` as it is a primary key and used for the conflict target
          l2_block_number: fragment("EXCLUDED.l2_block_number"),
          l1_transaction_hash: fragment("EXCLUDED.l1_transaction_hash"),
          l1_timestamp: fragment("EXCLUDED.l1_timestamp"),
          l1_block_number: fragment("EXCLUDED.l1_block_number"),
          output_root: fragment("EXCLUDED.output_root"),
          inserted_at: fragment("LEAST(?, EXCLUDED.inserted_at)", root.inserted_at),
          updated_at: fragment("GREATEST(?, EXCLUDED.updated_at)", root.updated_at)
        ]
      ],
      where:
        fragment(
          "(EXCLUDED.l2_block_number, EXCLUDED.l1_transaction_hash, EXCLUDED.l1_timestamp, EXCLUDED.l1_block_number, EXCLUDED.output_root) IS DISTINCT FROM (?, ?, ?, ?, ?)",
          root.l2_block_number,
          root.l1_transaction_hash,
          root.l1_timestamp,
          root.l1_block_number,
          root.output_root
        )
    )
  end
end
