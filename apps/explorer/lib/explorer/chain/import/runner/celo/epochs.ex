defmodule Explorer.Chain.Import.Runner.Celo.Epochs do
  @moduledoc """
  Bulk imports `t:Explorer.Chain.Celo.Epoch.t/0`.
  """

  require Ecto.Query
  import Ecto.Query, only: [from: 2]

  alias Ecto.{Changeset, Multi, Repo}
  alias Explorer.Chain.Celo.Epoch
  alias Explorer.Chain.Import
  alias Explorer.Prometheus.Instrumenter

  @behaviour Import.Runner

  # milliseconds
  @timeout 60_000

  @type imported :: [Epoch.t()]

  @impl Import.Runner
  def ecto_schema_module, do: Epoch

  @impl Import.Runner
  def option_key, do: :celo_epochs

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

    Multi.run(multi, :celo_epochs, fn repo, _ ->
      Instrumenter.block_import_stage_runner(
        fn -> insert(repo, changes_list, insert_options) end,
        :block_referencing,
        :celo_epochs,
        :celo_epochs
      )
    end)
  end

  @impl Import.Runner
  def timeout, do: @timeout

  @spec insert(Repo.t(), [map()], %{required(:timeout) => timeout(), required(:timestamps) => Import.timestamps()}) ::
          {:ok, [Epoch.t()]}
          | {:error, [Changeset.t()]}
  def insert(repo, changes_list, %{timeout: timeout, timestamps: timestamps} = _options) when is_list(changes_list) do
    # Enforce Celo.Epoch ShareLocks order (see docs: sharelock.md)
    ordered_changes_list = Enum.sort_by(changes_list, & &1.number)

    {:ok, inserted} =
      Import.insert_changes_list(
        repo,
        ordered_changes_list,
        for: Epoch,
        returning: true,
        timeout: timeout,
        timestamps: timestamps,
        conflict_target: [:number],
        on_conflict: default_on_conflict()
      )

    {:ok, inserted}
  end

  defp default_on_conflict do
    from(epoch in Epoch,
      update: [
        set: [
          start_block_number: fragment("COALESCE(EXCLUDED.start_block_number, ?)", epoch.start_block_number),
          end_block_number: fragment("COALESCE(EXCLUDED.end_block_number, ?)", epoch.end_block_number),
          start_processing_block_hash:
            fragment("COALESCE(EXCLUDED.start_processing_block_hash, ?)", epoch.start_processing_block_hash),
          end_processing_block_hash:
            fragment("COALESCE(EXCLUDED.end_processing_block_hash, ?)", epoch.end_processing_block_hash),
          fetched?: fragment("EXCLUDED.is_fetched"),
          inserted_at: fragment("LEAST(EXCLUDED.inserted_at, ?)", epoch.inserted_at),
          updated_at: fragment("GREATEST(?, EXCLUDED.updated_at)", epoch.updated_at)
        ]
      ],
      where:
        fragment("EXCLUDED.start_block_number IS DISTINCT FROM ?", epoch.start_block_number) or
          fragment("EXCLUDED.end_block_number IS DISTINCT FROM ?", epoch.end_block_number) or
          fragment("EXCLUDED.start_processing_block_hash IS DISTINCT FROM ?", epoch.start_processing_block_hash) or
          fragment("EXCLUDED.end_processing_block_hash IS DISTINCT FROM ?", epoch.end_processing_block_hash) or
          fragment("EXCLUDED.is_fetched IS DISTINCT FROM ?", epoch.fetched?)
    )
  end
end
