defmodule Explorer.Chain.Import.Runner.CeloVoterVotes do
  @moduledoc """
  Bulk imports Celo voter votes to the DB table.
  """

  require Ecto.Query

  alias Ecto.{Changeset, Multi, Repo}
  alias Explorer.Chain.{CeloPendingEpochOperation, Import}
  alias Explorer.Chain.CeloVoterVotes, as: CeloVoterVotesChain
  alias Explorer.Chain.Import.Runner.Util

  import Ecto.Query, only: [from: 2]

  @behaviour Import.Runner

  # milliseconds
  @timeout 60_000

  @type imported :: [CeloVoterVotesChain.t()]

  @impl Import.Runner
  def ecto_schema_module, do: CeloVoterVotesChain

  @impl Import.Runner
  def option_key, do: :celo_voter_votes

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
      Multi.run(multi, :insert_celo_voter_votes_items, fn repo, _ ->
        insert(repo, changes_list, insert_options)
      end)

    multi_chain
    |> Multi.run(:falsify_fetch_voter_votes, fn _, _ ->
      changes =
        changes_list
        |> Enum.each(fn votes ->
          CeloPendingEpochOperation.falsify_celo_pending_epoch_operation(
            votes.block_hash,
            :fetch_voter_votes
          )
        end)

      {:ok, changes}
    end)
  end

  @impl Import.Runner
  def timeout, do: @timeout

  @spec insert(Repo.t(), [map()], Util.insert_options()) ::
          {:ok, [CeloVoterVotesChain.t()]} | {:error, [Changeset.t()]}
  defp insert(repo, changes_list, %{timeout: timeout, timestamps: timestamps} = options) when is_list(changes_list) do
    on_conflict = Map.get_lazy(options, :on_conflict, &default_on_conflict/0)

    # Enforce ShareLocks order (see docs: sharelocks.md)
    uniq_changes_list =
      changes_list
      |> Enum.sort_by(&{&1.block_hash})
      |> Enum.dedup_by(&{&1.block_hash, &1.account_hash, &1.group_hash})

    {:ok, _} =
      Import.insert_changes_list(
        repo,
        uniq_changes_list,
        conflict_target: [:account_hash, :block_hash, :group_hash],
        on_conflict: on_conflict,
        for: CeloVoterVotesChain,
        returning: true,
        timeout: timeout,
        timestamps: timestamps
      )
  end

  defp default_on_conflict do
    from(
      account in CeloVoterVotesChain,
      update: [
        set: [
          active_votes: fragment("EXCLUDED.active_votes"),
          inserted_at: fragment("LEAST(?, EXCLUDED.inserted_at)", account.inserted_at),
          updated_at: fragment("GREATEST(?, EXCLUDED.updated_at)", account.updated_at)
        ]
      ]
    )
  end
end
