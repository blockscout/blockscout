defmodule Explorer.Chain.Import.Runner.TransactionActions do
  @moduledoc """
  Bulk imports `t:Explorer.Chain.TransactionAction.t/0`.
  """

  require Ecto.Query

  import Ecto.Query, only: [from: 2]

  alias Ecto.{Changeset, Multi, Repo}
  alias Explorer.Chain.{Import, TransactionAction}
  alias Explorer.Prometheus.Instrumenter

  @behaviour Import.Runner

  # milliseconds
  @timeout 60_000

  @type imported :: [TransactionAction.t()]

  @impl Import.Runner
  def ecto_schema_module, do: TransactionAction

  @impl Import.Runner
  def option_key, do: :transaction_actions

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

    Multi.run(multi, :insert_transaction_actions, fn repo, _ ->
      Instrumenter.block_import_stage_runner(
        fn -> insert(repo, changes_list, insert_options) end,
        :block_referencing,
        :transaction_actions,
        :transaction_actions
      )
    end)
  end

  @impl Import.Runner
  def timeout, do: @timeout

  @spec insert(Repo.t(), [map()], %{required(:timeout) => timeout(), required(:timestamps) => Import.timestamps()}) ::
          {:ok, [TransactionAction.t()]}
          | {:error, [Changeset.t()]}
  def insert(repo, changes_list, %{timeout: timeout, timestamps: timestamps} = options) when is_list(changes_list) do
    on_conflict = Map.get_lazy(options, :on_conflict, &default_on_conflict/0)

    # Enforce TransactionAction ShareLocks order (see docs: sharelock.md)
    ordered_changes_list = Enum.sort_by(changes_list, &{&1.hash, &1.log_index})

    {:ok, inserted} =
      Import.insert_changes_list(
        repo,
        ordered_changes_list,
        conflict_target: [:hash, :log_index],
        on_conflict: on_conflict,
        for: TransactionAction,
        returning: true,
        timeout: timeout,
        timestamps: timestamps
      )

    {:ok, inserted}
  end

  defp default_on_conflict do
    from(
      action in TransactionAction,
      update: [
        set: [
          # Don't update `hash` as it is part of the composite primary key and used for the conflict target
          # Don't update `log_index` as it is part of the composite primary key and used for the conflict target
          protocol: fragment("EXCLUDED.protocol"),
          data: fragment("EXCLUDED.data"),
          type: fragment("EXCLUDED.type"),
          inserted_at: fragment("LEAST(?, EXCLUDED.inserted_at)", action.inserted_at),
          updated_at: fragment("GREATEST(?, EXCLUDED.updated_at)", action.updated_at)
        ]
      ],
      where:
        fragment(
          "(EXCLUDED.protocol, EXCLUDED.data, EXCLUDED.type) IS DISTINCT FROM (?, ? ,?)",
          action.protocol,
          action.data,
          action.type
        )
    )
  end
end
