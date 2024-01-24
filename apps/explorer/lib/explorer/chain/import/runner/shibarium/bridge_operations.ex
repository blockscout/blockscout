defmodule Explorer.Chain.Import.Runner.Shibarium.BridgeOperations do
  @moduledoc """
  Bulk imports `t:Explorer.Chain.Shibarium.Bridge.t/0`.
  """

  require Ecto.Query

  import Ecto.Query, only: [from: 2]

  alias Ecto.{Changeset, Multi, Repo}
  alias Explorer.Chain.Import
  alias Explorer.Chain.Shibarium.Bridge, as: ShibariumBridge
  alias Explorer.Prometheus.Instrumenter

  @behaviour Import.Runner

  # milliseconds
  @timeout 60_000

  @type imported :: [ShibariumBridge.t()]

  @impl Import.Runner
  def ecto_schema_module, do: ShibariumBridge

  @impl Import.Runner
  def option_key, do: :shibarium_bridge_operations

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

    Multi.run(multi, :insert_shibarium_bridge_operations, fn repo, _ ->
      Instrumenter.block_import_stage_runner(
        fn -> insert(repo, changes_list, insert_options) end,
        :block_referencing,
        :shibarium_bridge_operations,
        :shibarium_bridge_operations
      )
    end)
  end

  @impl Import.Runner
  def timeout, do: @timeout

  @spec insert(Repo.t(), [map()], %{required(:timeout) => timeout(), required(:timestamps) => Import.timestamps()}) ::
          {:ok, [ShibariumBridge.t()]}
          | {:error, [Changeset.t()]}
  def insert(repo, changes_list, %{timeout: timeout, timestamps: timestamps} = options) when is_list(changes_list) do
    on_conflict = Map.get_lazy(options, :on_conflict, &default_on_conflict/0)

    # Enforce ShibariumBridge ShareLocks order (see docs: sharelock.md)
    ordered_changes_list =
      Enum.sort_by(changes_list, &{&1.operation_hash, &1.l1_transaction_hash, &1.l2_transaction_hash})

    {:ok, inserted} =
      Import.insert_changes_list(
        repo,
        ordered_changes_list,
        conflict_target: [:operation_hash, :l1_transaction_hash, :l2_transaction_hash],
        on_conflict: on_conflict,
        for: ShibariumBridge,
        returning: true,
        timeout: timeout,
        timestamps: timestamps
      )

    {:ok, inserted}
  end

  defp default_on_conflict do
    from(
      op in ShibariumBridge,
      update: [
        set: [
          # Don't update `operation_hash` as it is part of the composite primary key and used for the conflict target
          # Don't update `l1_transaction_hash` as it is part of the composite primary key and used for the conflict target
          # Don't update `l2_transaction_hash` as it is part of the composite primary key and used for the conflict target
          # Don't update `operation_type` as it is not changed
          user: fragment("EXCLUDED.user"),
          amount_or_id: fragment("EXCLUDED.amount_or_id"),
          erc1155_ids: fragment("EXCLUDED.erc1155_ids"),
          erc1155_amounts: fragment("EXCLUDED.erc1155_amounts"),
          l1_block_number: fragment("EXCLUDED.l1_block_number"),
          l2_block_number: fragment("EXCLUDED.l2_block_number"),
          token_type: fragment("EXCLUDED.token_type"),
          timestamp: fragment("EXCLUDED.timestamp"),
          inserted_at: fragment("LEAST(?, EXCLUDED.inserted_at)", op.inserted_at),
          updated_at: fragment("GREATEST(?, EXCLUDED.updated_at)", op.updated_at)
        ]
      ],
      where:
        fragment(
          "(EXCLUDED.user, EXCLUDED.amount_or_id, EXCLUDED.erc1155_ids, EXCLUDED.erc1155_amounts, EXCLUDED.operation_type, EXCLUDED.l1_block_number, EXCLUDED.l2_block_number, EXCLUDED.token_type, EXCLUDED.timestamp) IS DISTINCT FROM (?, ?, ?, ?, ?, ?, ?, ?, ?)",
          op.user,
          op.amount_or_id,
          op.erc1155_ids,
          op.erc1155_amounts,
          op.operation_type,
          op.l1_block_number,
          op.l2_block_number,
          op.token_type,
          op.timestamp
        )
    )
  end
end
