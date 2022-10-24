defmodule Explorer.Chain.Import.Runner.CeloUnlocked do
  @moduledoc """
  Bulk imports pending Celo to the DB table.
  """

  require Ecto.Query

  alias Ecto.{Changeset, Multi, Repo}
  alias Explorer.Chain.{CeloUnlocked, Import}
  alias Explorer.Chain.Import.Runner.Util

  @behaviour Import.Runner

  # milliseconds
  @timeout 60_000

  @type imported :: [CeloUnlocked.t()]

  @impl Import.Runner
  def ecto_schema_module, do: CeloUnlocked

  @impl Import.Runner
  def option_key, do: :celo_unlocked

  @impl Import.Runner
  def imported_table_row do
    %{
      value_type: "[#{ecto_schema_module()}.t()]",
      value_description: "List of `t:#{ecto_schema_module()}.t/0`s"
    }
  end

  @impl Import.Runner
  def run(multi, changes_list, options) do
    insert_options = Util.make_insert_options(option_key(), @timeout, options)

    # Enforce ShareLocks tables order (see docs: sharelocks.md)
    Multi.run(multi, :celo_unlocked, fn repo, _ ->
      insert(repo, changes_list, insert_options)
    end)
  end

  @impl Import.Runner
  def timeout, do: @timeout

  @spec insert(Repo.t(), [map()], Util.insert_options()) :: {:ok, [CeloUnlocked.t()]} | {:error, [Changeset.t()]}
  defp insert(repo, changes_list, %{timeout: timeout, timestamps: timestamps}) when is_list(changes_list) do
    # Enforce ShareLocks order (see docs: sharelocks.md)
    uniq_changes_list =
      changes_list
      |> Enum.sort_by(&{&1.account_address})
      |> Enum.uniq_by(&{&1.account_address})

    {:ok, _} =
      Import.insert_changes_list(
        repo,
        uniq_changes_list,
        for: CeloUnlocked,
        returning: true,
        timeout: timeout,
        timestamps: timestamps
      )
  end
end
