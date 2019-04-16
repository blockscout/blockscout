defmodule Explorer.Chain.Import.Runner.Validators do
  @moduledoc """
  Bulk imports `t:Explorer.Chain.Address.Name.t/0`.
  """

  require Ecto.Query

  alias Ecto.{Changeset, Multi, Repo}
  alias Explorer.Chain.{Import, Address}

  import Ecto.Query, only: [from: 2]

  @behaviour Import.Runner

  # milliseconds
  @timeout 60_000

  @type imported :: [Address.Name.t()]

  @impl Import.Runner
  def ecto_schema_module, do: Address.Name

  @impl Import.Runner
  def option_key, do: :validators

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
      |> Map.get(option_key(), %{})
      |> Map.take(~w(on_conflict timeout)a)
      |> Map.put_new(:timeout, @timeout)
      |> Map.put(:timestamps, timestamps)

    update_options = insert_options

    multi
    |> Multi.run(:deactivate_old_validators, fn repo, _ ->
      deactivate_old_validators(repo, changes_list, update_options)
    end)
    |> Multi.run(:validators, fn repo, _ ->
      insert(repo, changes_list, insert_options)
    end)
  end

  defp deactivate_old_validators(repo, changes_list, %{
    timeout: timeout,
    timestamps: _timestamps
  }) do
    address_hashes =
      changes_list
      |> MapSet.new(& &1.address_hash)
      |> Enum.sort()

    query =
      from(
        n in Address.Name,
        where: n.address_hash not in ^address_hashes,
        where: fragment("metadata->>'type'::text = 'validator'"),
        update: [
          set: [
            metadata:
              fragment("jsonb_set(metadata, '{active}', 'false'::jsonb)")
          ]
        ]
      )

    try do
      {_count, results} = repo.update_all(query, [], timeout: timeout)
      {:ok, results}
    rescue
      postgrex_error in Postgrex.Error ->
        {:error, %{exception: postgrex_error, address_hashes: address_hashes}}
    end
  end

  @impl Import.Runner
  def timeout, do: @timeout

  @spec insert(Repo.t(), [map()], %{
          optional(:on_conflict) => Import.Runner.on_conflict(),
          required(:timeout) => timeout,
          required(:timestamps) => Import.timestamps()
        }) ::
          {:ok, [Address.Name.t()]}
          | {:error, [Changeset.t()]}
  defp insert(repo, changes_list, %{timeout: timeout, timestamps: timestamps} = options) when is_list(changes_list) do
    on_conflict = Map.get_lazy(options, :on_conflict, &default_on_conflict/0)

    {:ok, _} =
      Import.insert_changes_list(
        repo,
        changes_list,
        conflict_target: [:address_hash, :name],
        on_conflict: on_conflict,
        for: Address.Name,
        returning: [:address_hash],
        timeout: timeout,
        timestamps: timestamps
      )
  end

  defp default_on_conflict do
    from(
      name in Address.Name,
      update: [
        set: [
          name: fragment("EXCLUDED.name"),
          metadata: fragment("EXCLUDED.metadata"),
          inserted_at: fragment("LEAST(?, EXCLUDED.inserted_at)", name.inserted_at),
          updated_at: fragment("GREATEST(?, EXCLUDED.updated_at)", name.updated_at)
        ]
      ],
      where:
        fragment(
          "(EXCLUDED.name, EXCLUDED.metadata) IS DISTINCT FROM (?, ?)",
          name.name,
          name.metadata
        )
    )
  end
end
