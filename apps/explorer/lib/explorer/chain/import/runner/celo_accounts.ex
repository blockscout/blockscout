defmodule Explorer.Chain.Import.Runner.CeloAccounts do
  @moduledoc """
  Bulk imports Celo accounts to the DB table.
  """

  require Ecto.Query

  alias Ecto.{Changeset, Multi, Repo}
  alias Explorer.Chain.{CeloAccount, Import}
  alias Explorer.Chain.Import.Runner.Util

  import Ecto.Query, only: [from: 2]

  @behaviour Import.Runner

  # milliseconds
  @timeout 60_000

  @type imported :: [CeloAccount.t()]

  @impl Import.Runner
  def ecto_schema_module, do: CeloAccount

  @impl Import.Runner
  def option_key, do: :celo_accounts

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
    |> Multi.run(:acquire_all_celo_accounts, fn repo, _ ->
      acquire_all_celo_accounts(repo)
    end)
    |> Multi.run(:insert_celo_accounts, fn repo, _ ->
      insert(repo, changes_list, insert_options)
    end)
  end

  @impl Import.Runner
  def timeout, do: @timeout

  defp acquire_all_celo_accounts(repo) do
    query =
      from(
        account in CeloAccount,
        order_by: account.address,
        lock: "FOR UPDATE"
      )

    accounts = repo.all(query)

    {:ok, accounts}
  end

  defp handle_dedup(lst) do
    Enum.reduce(lst, fn %{attestations_requested: req, attestations_fulfilled: full}, acc ->
      acc
      |> Map.put(:attestations_requested, req + acc.attestations_requested)
      |> Map.put(:attestations_fulfilled, full + acc.attestations_fulfilled)
    end)
  end

  @spec insert(Repo.t(), [map()], Util.insert_options()) :: {:ok, [CeloAccount.t()]} | {:error, [Changeset.t()]}
  defp insert(repo, changes_list, %{timeout: timeout, timestamps: timestamps} = options) when is_list(changes_list) do
    on_conflict = Map.get_lazy(options, :on_conflict, &default_on_conflict/0)

    uniq_changes_list =
      changes_list
      |> Enum.sort_by(& &1.address)
      |> Enum.group_by(& &1.address)
      |> Map.values()
      |> Enum.map(&handle_dedup/1)

    {:ok, _} =
      Import.insert_changes_list(
        repo,
        uniq_changes_list,
        conflict_target: :address,
        on_conflict: on_conflict,
        for: CeloAccount,
        returning: [:address],
        timeout: timeout,
        timestamps: timestamps
      )
  end

  defp default_on_conflict do
    from(
      account in CeloAccount,
      update: [
        set: [
          name: fragment("EXCLUDED.name"),
          url: fragment("EXCLUDED.url"),
          account_type: fragment("EXCLUDED.account_type"),
          nonvoting_locked_gold: fragment("EXCLUDED.nonvoting_locked_gold"),
          locked_gold: fragment("EXCLUDED.locked_gold"),
          attestations_requested: fragment("EXCLUDED.attestations_requested + ?", account.attestations_requested),
          attestations_fulfilled: fragment("EXCLUDED.attestations_fulfilled + ?", account.attestations_fulfilled),
          inserted_at: fragment("LEAST(?, EXCLUDED.inserted_at)", account.inserted_at),
          updated_at: fragment("GREATEST(?, EXCLUDED.updated_at)", account.updated_at)
        ]
      ]
    )
  end
end
