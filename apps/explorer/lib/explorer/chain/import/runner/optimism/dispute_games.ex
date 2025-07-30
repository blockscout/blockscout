defmodule Explorer.Chain.Import.Runner.Optimism.DisputeGames do
  @moduledoc """
  Bulk imports `t:Explorer.Chain.Optimism.DisputeGame.t/0`.
  """

  require Ecto.Query

  alias Ecto.{Changeset, Multi, Repo}
  alias Explorer.Chain.Import
  alias Explorer.Chain.Optimism.DisputeGame
  alias Explorer.Prometheus.Instrumenter

  import Ecto.Query, only: [from: 2]

  @behaviour Import.Runner

  # milliseconds
  @timeout 60_000

  @type imported :: [DisputeGame.t()]

  @impl Import.Runner
  def ecto_schema_module, do: DisputeGame

  @impl Import.Runner
  def option_key, do: :optimism_dispute_games

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

    Multi.run(multi, :insert_dispute_games, fn repo, _ ->
      Instrumenter.block_import_stage_runner(
        fn -> insert(repo, changes_list, insert_options) end,
        :block_referencing,
        :optimism_dispute_games,
        :optimism_dispute_games
      )
    end)
  end

  @impl Import.Runner
  def timeout, do: @timeout

  @spec insert(Repo.t(), [map()], %{required(:timeout) => timeout(), required(:timestamps) => Import.timestamps()}) ::
          {:ok, [DisputeGame.t()]}
          | {:error, [Changeset.t()]}
  def insert(repo, changes_list, %{timeout: timeout, timestamps: timestamps} = options) when is_list(changes_list) do
    on_conflict = Map.get_lazy(options, :on_conflict, &default_on_conflict/0)

    # Enforce DisputeGame ShareLocks order (see docs: sharelock.md)
    ordered_changes_list = Enum.sort_by(changes_list, & &1.index)

    {:ok, inserted} =
      Import.insert_changes_list(
        repo,
        ordered_changes_list,
        for: DisputeGame,
        returning: true,
        timeout: timeout,
        timestamps: timestamps,
        conflict_target: :index,
        on_conflict: on_conflict
      )

    {:ok, inserted}
  end

  defp default_on_conflict do
    from(
      game in DisputeGame,
      update: [
        set: [
          # don't update `index` as it is a primary key and used for the conflict target
          game_type: fragment("EXCLUDED.game_type"),
          address_hash: fragment("EXCLUDED.address_hash"),
          extra_data: fragment("EXCLUDED.extra_data"),
          created_at: fragment("EXCLUDED.created_at"),
          resolved_at: fragment("EXCLUDED.resolved_at"),
          status: fragment("EXCLUDED.status"),
          inserted_at: fragment("LEAST(?, EXCLUDED.inserted_at)", game.inserted_at),
          updated_at: fragment("GREATEST(?, EXCLUDED.updated_at)", game.updated_at)
        ]
      ],
      where:
        fragment(
          "(EXCLUDED.game_type, EXCLUDED.address_hash, EXCLUDED.extra_data, EXCLUDED.created_at, EXCLUDED.resolved_at, EXCLUDED.status) IS DISTINCT FROM (?, ?, ?, ?, ?, ?)",
          game.game_type,
          game.address_hash,
          game.extra_data,
          game.created_at,
          game.resolved_at,
          game.status
        )
    )
  end
end
