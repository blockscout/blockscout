defmodule Explorer.Chain.Import.Runner.CeloCoreContract do
  @moduledoc """
  Bulk imports Celo Core Contracts
  """
  alias Explorer.Chain.{CeloCoreContract, Import}
  alias Explorer.Chain.Import.Runner.Util

  alias Ecto.{Changeset, Multi, Repo}

  @behaviour Import.Runner

  # milliseconds
  @timeout 60_000

  @type imported :: [CeloCoreContract.t()]

  @impl Import.Runner
  def ecto_schema_module, do: CeloCoreContract

  @impl Import.Runner
  def option_key, do: :celo_core_contracts

  @impl Import.Runner
  def imported_table_row do
    %{
      value_type: "[#{ecto_schema_module()}.t()]",
      value_description: "List of `t:#{ecto_schema_module()}.t/0`s"
    }
  end

  @impl Import.Runner
  def timeout, do: @timeout

  @impl Import.Runner
  def run(multi, changes_list, options) do
    insert_options = Util.make_insert_options(option_key(), @timeout, options)

    # Enforce ShareLocks tables order (see docs: sharelocks.md)
    Multi.run(multi, :celo_core_contracts, fn repo, _ ->
      insert(repo, changes_list, insert_options)
    end)
  end

  @spec insert(Repo.t(), [map()], Util.insert_options()) ::
          {:ok, [CeloCoreContract.t()]} | {:error, [Changeset.t()]}
  defp insert(repo, changes_list, %{timeout: timeout, timestamps: timestamps} = options) when is_list(changes_list) do
    on_conflict = Map.get(options, :on_conflict, :nothing)

    # Enforce Log ShareLocks order (see docs: sharelocks.md)
    ordered_changes_list = Enum.sort_by(changes_list, &{&1.block_number, &1.log_index})

    {:ok, _} =
      Import.insert_changes_list(
        repo,
        ordered_changes_list,
        conflict_target: [:address_hash],
        on_conflict: on_conflict,
        for: CeloCoreContract,
        returning: true,
        timeout: timeout,
        timestamps: timestamps
      )
  end
end
