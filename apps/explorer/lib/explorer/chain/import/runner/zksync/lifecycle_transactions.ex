defmodule Explorer.Chain.Import.Runner.ZkSync.LifecycleTransactions do
  @moduledoc """
  Bulk imports `t:Explorer.Chain.ZkSync.LifecycleTransaction.t/0`.
  """

  require Ecto.Query

  alias Ecto.{Changeset, Multi, Repo}
  alias Explorer.Chain.Import
  alias Explorer.Chain.ZkSync.LifecycleTransaction
  alias Explorer.Prometheus.Instrumenter

  import Ecto.Query, only: [from: 2]

  @behaviour Import.Runner

  # milliseconds
  @timeout 60_000

  @type imported :: [LifecycleTransaction.t()]

  @impl Import.Runner
  def ecto_schema_module, do: LifecycleTransaction

  @impl Import.Runner
  def option_key, do: :zksync_lifecycle_transactions

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

    Multi.run(multi, :insert_zksync_lifecycle_transactions, fn repo, _ ->
      Instrumenter.block_import_stage_runner(
        fn -> insert(repo, changes_list, insert_options) end,
        :block_referencing,
        :zksync_lifecycle_transactions,
        :zksync_lifecycle_transactions
      )
    end)
  end

  @impl Import.Runner
  def timeout, do: @timeout

  @spec insert(Repo.t(), [map()], %{required(:timeout) => timeout(), required(:timestamps) => Import.timestamps()}) ::
          {:ok, [LifecycleTransaction.t()]}
          | {:error, [Changeset.t()]}
  def insert(repo, changes_list, %{timeout: timeout, timestamps: timestamps} = options) when is_list(changes_list) do
    on_conflict = Map.get_lazy(options, :on_conflict, &default_on_conflict/0)

    # Enforce ZkSync.LifecycleTransaction ShareLocks order (see docs: sharelock.md)
    ordered_changes_list = Enum.sort_by(changes_list, & &1.id)

    {:ok, inserted} =
      Import.insert_changes_list(
        repo,
        ordered_changes_list,
        for: LifecycleTransaction,
        returning: true,
        timeout: timeout,
        timestamps: timestamps,
        conflict_target: :hash,
        on_conflict: on_conflict
      )

    {:ok, inserted}
  end

  defp default_on_conflict do
    from(
      transaction in LifecycleTransaction,
      update: [
        set: [
          # don't update `id` as it is a primary key
          # don't update `hash` as it is a unique index and used for the conflict target
          timestamp: fragment("EXCLUDED.timestamp"),
          inserted_at: fragment("LEAST(?, EXCLUDED.inserted_at)", transaction.inserted_at),
          updated_at: fragment("GREATEST(?, EXCLUDED.updated_at)", transaction.updated_at)
        ]
      ],
      where:
        fragment(
          "(EXCLUDED.timestamp) IS DISTINCT FROM (?)",
          transaction.timestamp
        )
    )
  end
end
