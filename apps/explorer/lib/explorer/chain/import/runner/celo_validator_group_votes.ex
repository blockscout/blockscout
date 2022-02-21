defmodule Explorer.Chain.Import.Runner.CeloValidatorGroupVotes do
  @moduledoc """
  Bulk imports Celo voter rewards to the DB table.
  """

  require Ecto.Query

  alias Ecto.{Changeset, Multi, Repo}
  alias Explorer.Chain.{CeloPendingEpochOperation, CeloValidatorGroupVotes, Import}
  alias Explorer.Chain.Import.Runner.Util

  import Ecto.Query, only: [from: 2]

  @behaviour Import.Runner

  # milliseconds
  @timeout 60_000

  @type imported :: [CeloValidatorGroupVotes.t()]

  @impl Import.Runner
  def ecto_schema_module, do: CeloValidatorGroupVotes

  @impl Import.Runner
  def option_key, do: :celo_validator_group_votes

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
    multi_chain =
      Multi.run(multi, :insert_group_vote_items, fn repo, _ ->
        insert(repo, changes_list, insert_options)
      end)

    multi_chain
    |> Multi.run(:delete_celo_pending, fn _, _ ->
      changes =
        changes_list
        |> Enum.each(fn reward ->
          CeloPendingEpochOperation.falsify_or_delete_celo_pending_epoch_operation(
            reward.block_hash,
            :fetch_validator_group_data
          )
        end)

      {:ok, changes}
    end)
  end

  @impl Import.Runner
  def timeout, do: @timeout

  @spec insert(Repo.t(), [map()], Util.insert_options()) ::
          {:ok, [CeloValidatorGroupVotes.t()]} | {:error, [Changeset.t()]}
  defp insert(repo, changes_list, %{timeout: timeout, timestamps: timestamps} = options) when is_list(changes_list) do
    on_conflict = Map.get_lazy(options, :on_conflict, &default_on_conflict/0)

    # Enforce ShareLocks order (see docs: sharelocks.md)
    uniq_changes_list =
      changes_list
      |> Enum.sort_by(&{&1.block_hash})
      |> Enum.dedup_by(&{&1.block_hash})

    {:ok, _} =
      Import.insert_changes_list(
        repo,
        uniq_changes_list,
        conflict_target: [:block_hash, :group_hash],
        on_conflict: on_conflict,
        for: CeloValidatorGroupVotes,
        returning: true,
        timeout: timeout,
        timestamps: timestamps
      )
  end

  defp default_on_conflict do
    from(
      account in CeloValidatorGroupVotes,
      update: [
        set: [
          previous_block_active_votes: fragment("EXCLUDED.previous_block_active_votes"),
          inserted_at: fragment("LEAST(?, EXCLUDED.inserted_at)", account.inserted_at),
          updated_at: fragment("GREATEST(?, EXCLUDED.updated_at)", account.updated_at)
        ]
      ]
    )
  end
end
