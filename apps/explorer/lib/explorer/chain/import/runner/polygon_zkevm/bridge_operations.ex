defmodule Explorer.Chain.Import.Runner.PolygonZkevm.BridgeOperations do
  @moduledoc """
  Bulk imports `t:Explorer.Chain.PolygonZkevm.Bridge.t/0`.
  """

  require Ecto.Query

  import Ecto.Query, only: [from: 2]

  alias Ecto.{Changeset, Multi, Repo}
  alias Explorer.Chain.Import
  alias Explorer.Chain.PolygonZkevm.Bridge, as: PolygonZkevmBridge
  alias Explorer.Prometheus.Instrumenter

  @behaviour Import.Runner

  # milliseconds
  @timeout 60_000

  @type imported :: [PolygonZkevmBridge.t()]

  @impl Import.Runner
  def ecto_schema_module, do: PolygonZkevmBridge

  @impl Import.Runner
  def option_key, do: :polygon_zkevm_bridge_operations

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

    Multi.run(multi, :insert_polygon_zkevm_bridge_operations, fn repo, _ ->
      Instrumenter.block_import_stage_runner(
        fn -> insert(repo, changes_list, insert_options) end,
        :block_referencing,
        :polygon_zkevm_bridge_operations,
        :polygon_zkevm_bridge_operations
      )
    end)
  end

  @impl Import.Runner
  def timeout, do: @timeout

  @spec insert(Repo.t(), [map()], %{required(:timeout) => timeout(), required(:timestamps) => Import.timestamps()}) ::
          {:ok, [PolygonZkevmBridge.t()]}
          | {:error, [Changeset.t()]}
  def insert(repo, changes_list, %{timeout: timeout, timestamps: timestamps} = options) when is_list(changes_list) do
    on_conflict = Map.get_lazy(options, :on_conflict, &default_on_conflict/0)

    # Enforce PolygonZkevmBridge ShareLocks order (see docs: sharelock.md)
    ordered_changes_list = Enum.sort_by(changes_list, &{&1.type, &1.index})

    {:ok, inserted} =
      Import.insert_changes_list(
        repo,
        ordered_changes_list,
        conflict_target: [:type, :index],
        on_conflict: on_conflict,
        for: PolygonZkevmBridge,
        returning: true,
        timeout: timeout,
        timestamps: timestamps
      )

    {:ok, inserted}
  end

  defp default_on_conflict do
    from(
      op in PolygonZkevmBridge,
      update: [
        set: [
          # Don't update `type` as it is part of the composite primary key and used for the conflict target
          # Don't update `index` as it is part of the composite primary key and used for the conflict target
          l1_transaction_hash: fragment("COALESCE(EXCLUDED.l1_transaction_hash, ?)", op.l1_transaction_hash),
          l2_transaction_hash: fragment("COALESCE(EXCLUDED.l2_transaction_hash, ?)", op.l2_transaction_hash),
          l1_token_id: fragment("COALESCE(EXCLUDED.l1_token_id, ?)", op.l1_token_id),
          l1_token_address: fragment("COALESCE(EXCLUDED.l1_token_address, ?)", op.l1_token_address),
          l2_token_address: fragment("COALESCE(EXCLUDED.l2_token_address, ?)", op.l2_token_address),
          amount: fragment("EXCLUDED.amount"),
          block_number: fragment("COALESCE(EXCLUDED.block_number, ?)", op.block_number),
          block_timestamp: fragment("COALESCE(EXCLUDED.block_timestamp, ?)", op.block_timestamp),
          inserted_at: fragment("LEAST(?, EXCLUDED.inserted_at)", op.inserted_at),
          updated_at: fragment("GREATEST(?, EXCLUDED.updated_at)", op.updated_at)
        ]
      ],
      where:
        fragment(
          "(EXCLUDED.l1_transaction_hash, EXCLUDED.l2_transaction_hash, EXCLUDED.l1_token_id, EXCLUDED.l1_token_address, EXCLUDED.l2_token_address, EXCLUDED.amount, EXCLUDED.block_number, EXCLUDED.block_timestamp) IS DISTINCT FROM (?, ?, ?, ?, ?, ?, ?, ?)",
          op.l1_transaction_hash,
          op.l2_transaction_hash,
          op.l1_token_id,
          op.l1_token_address,
          op.l2_token_address,
          op.amount,
          op.block_number,
          op.block_timestamp
        )
    )
  end
end
