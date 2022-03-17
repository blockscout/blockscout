defmodule Explorer.Chain.Import.Runner.CeloContractEvent do
  @moduledoc """
  Bulk imports Celo contract events
  """
  alias Explorer.Chain.{CeloContractEvent, Import}
  alias Explorer.Chain.Import.Runner.Util

  alias Ecto.{Changeset, Multi, Repo}

  @behaviour Import.Runner

  # milliseconds
  @timeout 60_000

  @type imported :: [CeloContractEvent.t()]

  @impl Import.Runner
  def ecto_schema_module, do: CeloContractEvent

  @impl Import.Runner
  def option_key, do: :celo_contract_events

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
    Multi.run(multi, :celo_contract_event, fn repo, _ ->
      insert(repo, changes_list, insert_options)
    end)
  end

  @spec insert(Repo.t(), [map()], Util.insert_options()) ::
          {:ok, [CeloContractEvent.t()]} | {:error, [Changeset.t()]}
  defp insert(repo, changes_list, %{timeout: timeout, timestamps: timestamps} = options) when is_list(changes_list) do
    on_conflict = Map.get(options, :on_conflict, :nothing)

    # Enforce Log ShareLocks order (see docs: sharelocks.md)
    ordered_changes_list = Enum.sort_by(changes_list, &{&1.block_number, &1.log_index})

    {:ok, _} =
      Import.insert_changes_list(
        repo,
        ordered_changes_list,
        conflict_target: [:block_number, :log_index],
        on_conflict: on_conflict,
        for: CeloContractEvent,
        returning: true,
        timeout: timeout,
        timestamps: timestamps
      )
  end
end
