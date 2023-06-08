defmodule Explorer.Chain.Import.Runner.OptimismFrameSequences do
  @moduledoc """
  Bulk imports `t:Explorer.Chain.OptimismFrameSequence.t/0`.
  """

  require Ecto.Query

  alias Ecto.{Changeset, Multi, Repo}
  alias Explorer.Chain.{Import, OptimismFrameSequence}
  alias Explorer.Prometheus.Instrumenter

  import Ecto.Query, only: [from: 2]

  @behaviour Import.Runner

  # milliseconds
  @timeout 60_000

  @type imported :: [OptimismFrameSequence.t()]

  @impl Import.Runner
  def ecto_schema_module, do: OptimismFrameSequence

  @impl Import.Runner
  def option_key, do: :optimism_frame_sequences

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

    Multi.run(multi, :insert_frame_sequences, fn repo, _ ->
      Instrumenter.block_import_stage_runner(
        fn -> insert(repo, changes_list, insert_options) end,
        :block_referencing,
        :optimism_frame_sequences,
        :optimism_frame_sequences
      )
    end)
  end

  @impl Import.Runner
  def timeout, do: @timeout

  @spec insert(Repo.t(), [map()], %{required(:timeout) => timeout(), required(:timestamps) => Import.timestamps()}) ::
          {:ok, [OptimismFrameSequence.t()]}
          | {:error, [Changeset.t()]}
  def insert(repo, changes_list, %{timeout: timeout, timestamps: timestamps} = options) when is_list(changes_list) do
    on_conflict = Map.get_lazy(options, :on_conflict, &default_on_conflict/0)

    # Enforce OptimismFrameSequence ShareLocks order (see docs: sharelock.md)
    ordered_changes_list = Enum.sort_by(changes_list, & &1.id)

    {:ok, inserted} =
      Import.insert_changes_list(
        repo,
        ordered_changes_list,
        for: OptimismFrameSequence,
        returning: true,
        timeout: timeout,
        timestamps: timestamps,
        conflict_target: :id,
        on_conflict: on_conflict
      )

    {:ok, inserted}
  end

  defp default_on_conflict do
    from(
      fs in OptimismFrameSequence,
      update: [
        set: [
          # don't update `id` as it is a primary key and used for the conflict target
          l1_transaction_hashes: fragment("EXCLUDED.l1_transaction_hashes"),
          l1_timestamp: fragment("EXCLUDED.l1_timestamp"),
          inserted_at: fragment("LEAST(?, EXCLUDED.inserted_at)", fs.inserted_at),
          updated_at: fragment("GREATEST(?, EXCLUDED.updated_at)", fs.updated_at)
        ]
      ],
      where:
        fragment(
          "(EXCLUDED.l1_transaction_hashes, EXCLUDED.l1_timestamp) IS DISTINCT FROM (?, ?)",
          fs.l1_transaction_hashes,
          fs.l1_timestamp
        )
    )
  end
end
