defmodule Explorer.Chain.Import.Runner.Celo.AggregatedElectionRewards do
  @moduledoc """
  Bulk imports `t:Explorer.Chain.Celo.AggregatedElectionReward.t/0`.
  """

  require Ecto.Query

  alias Ecto.{Changeset, Multi, Repo}
  alias Explorer.Chain.Celo.AggregatedElectionReward
  alias Explorer.Chain.Import
  alias Explorer.Prometheus.Instrumenter

  @behaviour Import.Runner

  # milliseconds
  @timeout 60_000

  @type imported :: [AggregatedElectionReward.t()]

  @impl Import.Runner
  def ecto_schema_module, do: AggregatedElectionReward

  @impl Import.Runner
  def option_key, do: :celo_aggregated_election_rewards

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

    multi
    |> Multi.run(:insert_celo_aggregated_election_rewards, fn repo, _ ->
      Instrumenter.block_import_stage_runner(
        fn -> insert(repo, changes_list, insert_options) end,
        :block_referencing,
        :celo_aggregated_election_rewards,
        :celo_aggregated_election_rewards
      )
    end)
  end

  @impl Import.Runner
  def timeout, do: @timeout

  @spec insert(Repo.t(), [map()], %{required(:timeout) => timeout(), required(:timestamps) => Import.timestamps()}) ::
          {:ok, [AggregatedElectionReward.t()]}
          | {:error, [Changeset.t()]}
  def insert(repo, changes_list, %{timeout: timeout, timestamps: timestamps} = _options) when is_list(changes_list) do
    # Enforce Celo.AggregatedElectionReward ShareLocks order (see docs: sharelock.md)
    ordered_changes_list = Enum.sort_by(changes_list, &{&1.type, &1.epoch_number})

    {:ok, inserted} =
      Import.insert_changes_list(
        repo,
        ordered_changes_list,
        for: AggregatedElectionReward,
        returning: true,
        timeout: timeout,
        timestamps: timestamps,
        conflict_target: [:type, :epoch_number],
        on_conflict: :replace_all
      )

    {:ok, inserted}
  end
end
