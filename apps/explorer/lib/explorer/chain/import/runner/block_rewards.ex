defmodule Explorer.Chain.Import.Runner.Block.Rewards do
  @moduledoc """
  Bulk imports `t:Explorer.Chain.Block.Reward.t/0`.
  """

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
          required(:timeout) => timeout,
          required(:timestamps) => Import.timestamps()
        }) :: {:ok, [Reward.t()]} | {:error, [Changeset.t()]}
  defp insert(repo, changes_list, %{timeout: timeout, timestamps: timestamps})
       when is_list(changes_list) do
    Import.insert_changes_list(
      repo,
      changes_list,
      conflict_target: [:address_hash, :address_type, :block_hash],
      on_conflict: :nothing,
      for: ecto_schema_module(),
      returning: true,
      timeout: timeout,
      timestamps: timestamps
    )
  end
end
