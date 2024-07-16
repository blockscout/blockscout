defmodule Explorer.Chain.Import.Runner.PolygonZkevm.BridgeL1Tokens do
  @moduledoc """
  Bulk imports `t:Explorer.Chain.PolygonZkevm.BridgeL1Token.t/0`.
  """

  require Ecto.Query

  import Ecto.Query, only: [from: 2]

  alias Ecto.{Changeset, Multi, Repo}
  alias Explorer.Chain.Import
  alias Explorer.Chain.PolygonZkevm.BridgeL1Token
  alias Explorer.Prometheus.Instrumenter

  @behaviour Import.Runner

  # milliseconds
  @timeout 60_000

  @type imported :: [BridgeL1Token.t()]

  @impl Import.Runner
  def ecto_schema_module, do: BridgeL1Token

  @impl Import.Runner
  def option_key, do: :polygon_zkevm_bridge_l1_tokens

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

    Multi.run(multi, :insert_polygon_zkevm_bridge_l1_tokens, fn repo, _ ->
      Instrumenter.block_import_stage_runner(
        fn -> insert(repo, changes_list, insert_options) end,
        :block_referencing,
        :polygon_zkevm_bridge_l1_tokens,
        :polygon_zkevm_bridge_l1_tokens
      )
    end)
  end

  @impl Import.Runner
  def timeout, do: @timeout

  @spec insert(Repo.t(), [map()], %{required(:timeout) => timeout(), required(:timestamps) => Import.timestamps()}) ::
          {:ok, [BridgeL1Token.t()]}
          | {:error, [Changeset.t()]}
  def insert(repo, changes_list, %{timeout: timeout, timestamps: timestamps} = options) when is_list(changes_list) do
    on_conflict = Map.get_lazy(options, :on_conflict, &default_on_conflict/0)

    # Enforce BridgeL1Token ShareLocks order (see docs: sharelock.md)
    ordered_changes_list = Enum.sort_by(changes_list, &{&1.address})

    {:ok, inserted} =
      Import.insert_changes_list(
        repo,
        ordered_changes_list,
        conflict_target: :address,
        on_conflict: on_conflict,
        for: BridgeL1Token,
        returning: true,
        timeout: timeout,
        timestamps: timestamps
      )

    {:ok, inserted}
  end

  defp default_on_conflict do
    from(
      t in BridgeL1Token,
      update: [
        set: [
          decimals: fragment("EXCLUDED.decimals"),
          symbol: fragment("EXCLUDED.symbol"),
          inserted_at: fragment("LEAST(?, EXCLUDED.inserted_at)", t.inserted_at),
          updated_at: fragment("GREATEST(?, EXCLUDED.updated_at)", t.updated_at)
        ]
      ],
      where:
        fragment(
          "(EXCLUDED.decimals, EXCLUDED.symbol) IS DISTINCT FROM (?, ?)",
          t.decimals,
          t.symbol
        )
    )
  end
end
