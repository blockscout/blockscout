defmodule Explorer.Chain.Import.Runner.Scroll.BridgeOperations do
  @moduledoc """
  Bulk imports `Explorer.Chain.Scroll.Bridge`.
  """

  require Ecto.Query

  import Ecto.Query, only: [from: 2]

  alias Ecto.{Changeset, Multi, Repo}
  alias Explorer.Chain.Import
  alias Explorer.Chain.Scroll.Bridge, as: ScrollBridge
  alias Explorer.Prometheus.Instrumenter

  @behaviour Import.Runner

  # milliseconds
  @timeout 60_000

  @type imported :: [ScrollBridge.t()]

  @impl Import.Runner
  def ecto_schema_module, do: ScrollBridge

  @impl Import.Runner
  def option_key, do: :scroll_bridge_operations

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

    Multi.run(multi, :insert_scroll_bridge_operations, fn repo, _ ->
      Instrumenter.block_import_stage_runner(
        fn -> insert(repo, changes_list, insert_options) end,
        :block_referencing,
        :scroll_bridge_operations,
        :scroll_bridge_operations
      )
    end)
  end

  @impl Import.Runner
  def timeout, do: @timeout

  @spec insert(Repo.t(), [map()], %{required(:timeout) => timeout(), required(:timestamps) => Import.timestamps()}) ::
          {:ok, [ScrollBridge.t()]}
          | {:error, [Changeset.t()]}
  def insert(repo, changes_list, %{timeout: timeout, timestamps: timestamps} = options) when is_list(changes_list) do
    on_conflict = Map.get_lazy(options, :on_conflict, &default_on_conflict/0)

    # Enforce ScrollBridge ShareLocks order (see docs: sharelock.md)
    ordered_changes_list = Enum.sort_by(changes_list, &{&1.type, &1.message_hash})

    {:ok, inserted} =
      Import.insert_changes_list(
        repo,
        ordered_changes_list,
        conflict_target: [:type, :message_hash],
        on_conflict: on_conflict,
        for: ScrollBridge,
        returning: true,
        timeout: timeout,
        timestamps: timestamps
      )

    {:ok, inserted}
  end

  defp default_on_conflict do
    from(
      sb in ScrollBridge,
      update: [
        set: [
          # Don't update `type` as it is part of the composite primary key and used for the conflict target
          # Don't update `message_hash` as it is part of the composite primary key and used for the conflict target
          index: fragment("COALESCE(EXCLUDED.index, ?)", sb.index),
          l1_transaction_hash: fragment("COALESCE(EXCLUDED.l1_transaction_hash, ?)", sb.l1_transaction_hash),
          l2_transaction_hash: fragment("COALESCE(EXCLUDED.l2_transaction_hash, ?)", sb.l2_transaction_hash),
          amount: fragment("COALESCE(EXCLUDED.amount, ?)", sb.amount),
          block_number: fragment("COALESCE(EXCLUDED.block_number, ?)", sb.block_number),
          block_timestamp: fragment("COALESCE(EXCLUDED.block_timestamp, ?)", sb.block_timestamp),
          inserted_at: fragment("LEAST(?, EXCLUDED.inserted_at)", sb.inserted_at),
          updated_at: fragment("GREATEST(?, EXCLUDED.updated_at)", sb.updated_at)
        ]
      ],
      where:
        fragment(
          "(EXCLUDED.index, EXCLUDED.l1_transaction_hash, EXCLUDED.l2_transaction_hash, EXCLUDED.amount, EXCLUDED.block_number, EXCLUDED.block_timestamp) IS DISTINCT FROM (?, ?, ?, ?, ?, ?)",
          sb.index,
          sb.l1_transaction_hash,
          sb.l2_transaction_hash,
          sb.amount,
          sb.block_number,
          sb.block_timestamp
        )
    )
  end
end
