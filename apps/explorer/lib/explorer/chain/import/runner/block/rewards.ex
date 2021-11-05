defmodule Explorer.Chain.Import.Runner.Block.Rewards do
  @moduledoc """
  Bulk imports `t:Explorer.Chain.Block.Reward.t/0`.
  """

  import Ecto.Query, only: [from: 2]
  require Logger

  alias Ecto.{Changeset, Multi, Repo}
  alias Explorer.Chain.Block.Reward
  alias Explorer.Chain.Import

  @behaviour Import.Runner

  # milliseconds
  @timeout 60_000

  @type imported :: [Reward.t()]

  @impl Import.Runner
  def ecto_schema_module, do: Reward

  @impl Import.Runner
  def option_key, do: :block_rewards

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
      |> Map.put_new(:timeout, @timeout)
      |> Map.put(:timestamps, timestamps)

    Multi.run(multi, option_key(), fn repo, _ -> insert(repo, changes_list, insert_options) end)
  end

  @impl Import.Runner
  def timeout, do: @timeout

  @spec insert(Repo.t(), [map()], %{
          optional(:on_conflict) => Import.Runner.on_conflict(),
          required(:timeout) => timeout,
          required(:timestamps) => Import.timestamps()
        }) :: {:ok, [Reward.t()]} | {:error, [Changeset.t()]}
  defp insert(repo, changes_list, %{timeout: timeout, timestamps: timestamps} = options)
       when is_list(changes_list) do
    Logger.info(["### Block rewards insert started ###"])
    on_conflict = Map.get_lazy(options, :on_conflict, &default_on_conflict/0)

    # Enforce Reward ShareLocks order (see docs: sharelocks.md)
    ordered_changes_list = Enum.sort_by(changes_list, &{&1.block_hash, &1.address_hash, &1.address_type})

    {:ok, block_rewards} =
      Import.insert_changes_list(
        repo,
        ordered_changes_list,
        conflict_target: [:address_hash, :address_type, :block_hash],
        on_conflict: on_conflict,
        for: ecto_schema_module(),
        returning: true,
        timeout: timeout,
        timestamps: timestamps
      )

    Logger.info(["### Block rewards insert finished ###"])

    {:ok, block_rewards}
  end

  defp default_on_conflict do
    from(reward in Reward,
      update: [set: [reward: fragment("EXCLUDED.reward")]],
      where: fragment("EXCLUDED.reward IS DISTINCT FROM ?", reward.reward)
    )
  end
end
