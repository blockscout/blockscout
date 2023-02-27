defmodule Explorer.Chain.Import.Runner.OptimismDeposits do
  @moduledoc """
  Bulk imports `t:Explorer.Chain.OptimismDeposit.t/0`.
  """

  require Ecto.Query

  alias Ecto.{Changeset, Multi, Repo}
  alias Explorer.Chain.{Import, OptimismDeposit}
  alias Explorer.Prometheus.Instrumenter

  import Ecto.Query, only: [from: 2]

  @behaviour Import.Runner

  # milliseconds
  @timeout 60_000

  @type imported :: [OptimismDeposit.t()]

  @impl Import.Runner
  def ecto_schema_module, do: OptimismDeposit

  @impl Import.Runner
  def option_key, do: :optimism_deposits

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

    Multi.run(multi, :insert_optimism_deposits, fn repo, _ ->
      Instrumenter.block_import_stage_runner(
        fn -> insert(repo, changes_list, insert_options) end,
        :block_referencing,
        :insert_optimism_deposits,
        :insert_optimism_deposits
      )
    end)
  end

  @impl Import.Runner
  def timeout, do: @timeout

  @spec insert(Repo.t(), [map()], %{required(:timeout) => timeout(), required(:timestamps) => Import.timestamps()}) ::
          {:ok, [OptimismDeposit.t()]}
          | {:error, [Changeset.t()]}
  def insert(repo, changes_list, %{timeout: timeout, timestamps: timestamps} = options) when is_list(changes_list) do
    on_conflict = Map.get_lazy(options, :on_conflict, &default_on_conflict/0)

    # Enforce OptimismDeposit ShareLocks order (see docs: sharelock.md)
    ordered_changes_list = Enum.sort_by(changes_list, & &1.l2_tx_hash)

    {:ok, inserted} =
      Import.insert_changes_list(
        repo,
        ordered_changes_list,
        for: OptimismDeposit,
        returning: true,
        timeout: timeout,
        timestamps: timestamps,
        conflict_target: :l2_tx_hash,
        on_conflict: on_conflict
      )

    {:ok, inserted}
  end

  defp default_on_conflict do
    from(
      deposit in OptimismDeposit,
      update: [
        set: [
          # don't update `l2_tx_hash` as it is a primary key and used for the conflict target
          l1_block_number: fragment("EXCLUDED.l1_block_number"),
          l1_block_timestamp: fragment("EXCLUDED.l1_block_timestamp"),
          l1_tx_hash: fragment("EXCLUDED.l1_tx_hash"),
          l1_tx_origin: fragment("EXCLUDED.l1_tx_origin"),
          inserted_at: fragment("LEAST(?, EXCLUDED.inserted_at)", deposit.inserted_at),
          updated_at: fragment("GREATEST(?, EXCLUDED.updated_at)", deposit.updated_at)
        ]
      ],
      where:
        fragment(
          "(EXCLUDED.l1_block_number, EXCLUDED.l1_block_timestamp, EXCLUDED.l1_tx_hash, EXCLUDED.l1_tx_origin) IS DISTINCT FROM (?, ?, ?, ?)",
          deposit.l1_block_number,
          deposit.l1_block_timestamp,
          deposit.l1_tx_hash,
          deposit.l1_tx_origin
        )
    )
  end
end
