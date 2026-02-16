defmodule Explorer.Chain.Import.Runner.Signet.Fills do
  @moduledoc """
    Bulk imports of Explorer.Chain.Signet.Fill.
  """

  require Ecto.Query

  import Ecto.Query, only: [from: 2]

  alias Ecto.{Changeset, Multi, Repo}
  alias Explorer.Chain.Signet.Fill
  alias Explorer.Chain.Import
  alias Explorer.Prometheus.Instrumenter

  @behaviour Import.Runner

  # milliseconds
  @timeout 60_000

  @type imported :: [Fill.t()]

  @impl Import.Runner
  def ecto_schema_module, do: Fill

  @impl Import.Runner
  def option_key, do: :signet_fills

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

    Multi.run(multi, Fill.insert_result_key(), fn repo, _ ->
      Instrumenter.block_import_stage_runner(
        fn -> insert(repo, changes_list, insert_options) end,
        :block_referencing,
        :signet_fills,
        :signet_fills
      )
    end)
  end

  @impl Import.Runner
  def timeout, do: @timeout

  @spec insert(Repo.t(), [map()], %{required(:timeout) => timeout(), required(:timestamps) => Import.timestamps()}) ::
          {:ok, [Fill.t()]}
          | {:error, [Changeset.t()]}
  def insert(repo, changes_list, %{timeout: timeout, timestamps: timestamps} = options) when is_list(changes_list) do
    on_conflict = Map.get_lazy(options, :on_conflict, &default_on_conflict/0)

    # Enforce Fill ShareLocks order (see docs: sharelock.md)
    ordered_changes_list = Enum.sort_by(changes_list, &{&1.outputs_witness_hash, &1.chain_type})

    {:ok, inserted} =
      Import.insert_changes_list(
        repo,
        ordered_changes_list,
        conflict_target: [:outputs_witness_hash, :chain_type],
        on_conflict: on_conflict,
        for: Fill,
        returning: true,
        timeout: timeout,
        timestamps: timestamps
      )

    {:ok, inserted}
  end

  defp default_on_conflict do
    from(
      f in Fill,
      update: [
        set: [
          # Don't update composite primary key fields
          block_number: fragment("COALESCE(EXCLUDED.block_number, ?)", f.block_number),
          transaction_hash: fragment("COALESCE(EXCLUDED.transaction_hash, ?)", f.transaction_hash),
          log_index: fragment("COALESCE(EXCLUDED.log_index, ?)", f.log_index),
          outputs_json: fragment("COALESCE(EXCLUDED.outputs_json, ?)", f.outputs_json),
          inserted_at: fragment("LEAST(?, EXCLUDED.inserted_at)", f.inserted_at),
          updated_at: fragment("GREATEST(?, EXCLUDED.updated_at)", f.updated_at)
        ]
      ],
      where:
        fragment(
          "(EXCLUDED.block_number, EXCLUDED.transaction_hash, EXCLUDED.log_index, EXCLUDED.outputs_json) IS DISTINCT FROM (?, ?, ?, ?)",
          f.block_number,
          f.transaction_hash,
          f.log_index,
          f.outputs_json
        )
    )
  end
end
