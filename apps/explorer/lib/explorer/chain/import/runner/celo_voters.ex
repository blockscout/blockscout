defmodule Explorer.Chain.Import.Runner.CeloVoters do
  @moduledoc """
  Bulk imports Celo validator groups to the DB table.
  """

  require Ecto.Query

  alias Ecto.{Changeset, Multi, Repo}
  alias Explorer.Chain.{CeloVoters, Import}
  alias Explorer.Chain.Import.Runner.Util

  import Ecto.Query, only: [from: 2]

  @behaviour Import.Runner

  # milliseconds
  @timeout 60_000

  @type imported :: [CeloVoters.t()]

  @impl Import.Runner
  def ecto_schema_module, do: CeloVoters

  @impl Import.Runner
  def option_key, do: :celo_voters

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
    multi
    |> Multi.run(:acquire_all_items, fn repo, _ ->
      acquire_all_items(repo)
    end)
    |> Multi.run(:insert_celo_voters, fn repo, _ ->
      insert(repo, changes_list, insert_options)
    end)
  end

  @impl Import.Runner
  def timeout, do: @timeout

  defp acquire_all_items(repo) do
    query =
      from(
        account in CeloVoters,
        # Enforce ShareLocks order (see docs: sharelocks.md)
        order_by: [account.group_address_hash, account.voter_address_hash],
        lock: "FOR UPDATE"
      )

    accounts = repo.all(query)

    {:ok, accounts}
  end

  @spec insert(Repo.t(), [map()], Util.insert_options()) :: {:ok, [CeloVoters.t()]} | {:error, [Changeset.t()]}
  defp insert(repo, changes_list, %{timeout: timeout, timestamps: timestamps} = options) when is_list(changes_list) do
    on_conflict = Map.get_lazy(options, :on_conflict, &default_on_conflict/0)

    # Enforce ShareLocks order (see docs: sharelocks.md)
    uniq_changes_list =
      changes_list
      |> Enum.sort_by(&{&1.group_address_hash, &1.voter_address_hash})
      |> Enum.uniq_by(&{&1.group_address_hash, &1.voter_address_hash})

    Import.insert_changes_list(
      repo,
      uniq_changes_list,
      conflict_target: [:group_address_hash, :voter_address_hash],
      on_conflict: on_conflict,
      for: CeloVoters,
      returning: [:group_address_hash, :voter_address_hash],
      timeout: timeout,
      timestamps: timestamps
    )
  end

  defp default_on_conflict do
    from(
      account in CeloVoters,
      update: [
        set: [
          total: fragment("EXCLUDED.total"),
          units: fragment("EXCLUDED.units"),
          pending: fragment("EXCLUDED.pending"),
          active: fragment("EXCLUDED.active"),
          inserted_at: fragment("LEAST(?, EXCLUDED.inserted_at)", account.inserted_at),
          updated_at: fragment("GREATEST(?, EXCLUDED.updated_at)", account.updated_at)
        ]
      ]
    )
  end
end
