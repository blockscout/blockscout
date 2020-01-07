defmodule Explorer.Chain.Import.Runner.Address.Names do
  @moduledoc """
  Bulk imports address names the DB table.
  """

  require Ecto.Query

  alias Ecto.{Changeset, Multi, Repo}
  alias Explorer.Chain.{Address, Import}
  alias Explorer.Chain.Import.Runner.Util

  import Ecto.Query, only: [from: 2]

  @behaviour Import.Runner

  # milliseconds
  @timeout 60_000

  @type imported :: [Address.Name.t()]

  @impl Import.Runner
  def ecto_schema_module, do: Address.Name

  @impl Import.Runner
  def option_key, do: :account_names

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
    |> Multi.run(:acquire_all_names, fn repo, _ ->
      acquire_all_names(repo)
    end)
    |> Multi.run(:insert_names, fn repo, _ ->
      insert(repo, changes_list, insert_options)
    end)
  end

  @impl Import.Runner
  def timeout, do: @timeout

  defp acquire_all_names(repo) do
    query =
      from(
        account in Address.Name,
        order_by: [account.address_hash, account.name],
        lock: "FOR UPDATE"
      )

    accounts = repo.all(query)

    {:ok, accounts}
  end

  @spec insert(Repo.t(), [map()], Util.insert_options()) :: {:ok, [Address.Name.t()]} | {:error, [Changeset.t()]}
  defp insert(repo, changes_list, %{timeout: timeout, timestamps: timestamps} = options) when is_list(changes_list) do
    uniq_changes_list =
      changes_list
      |> Enum.sort_by(&{&1.address_hash, &1.name})
      |> Enum.dedup_by(&{&1.address_hash, &1.name})

    on_conflict = Map.get_lazy(options, :on_conflict, &default_on_conflict/0)

    {:ok, _} =
      Import.insert_changes_list(
        repo,
        uniq_changes_list,
        conflict_target: [:address_hash, :name],
        on_conflict: on_conflict,
        for: Address.Name,
        returning: true,
        timeout: timeout,
        timestamps: timestamps
      )
  end

  defp default_on_conflict do
    from(
      name in Address.Name,
      update: [
        set: [
          primary: fragment("EXCLUDED.primary"),
          metadata: fragment("EXCLUDED.metadata"),
          inserted_at: fragment("LEAST(?, EXCLUDED.inserted_at)", name.inserted_at),
          updated_at: fragment("GREATEST(?, EXCLUDED.updated_at)", name.updated_at)
        ]
      ]
    )
  end
end
