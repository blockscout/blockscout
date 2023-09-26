defmodule Explorer.Chain.Import.Runner.TokenInstances do
  @moduledoc """
  Bulk imports `t:Explorer.Chain.TokenInstances.t/0`.
  """

  require Ecto.Query

  alias Ecto.{Changeset, Multi, Repo}
  alias Explorer.Chain.Import
  alias Explorer.Chain.Token.Instance, as: TokenInstance
  alias Explorer.Prometheus.Instrumenter

  import Ecto.Query, only: [from: 2]

  @behaviour Import.Runner

  # milliseconds
  @timeout 60_000

  @type imported :: [TokenInstance.t()]

  @impl Import.Runner
  def ecto_schema_module, do: TokenInstance

  @impl Import.Runner
  def option_key, do: :token_instances

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

    Multi.run(multi, :token_instances, fn repo, _ ->
      Instrumenter.block_import_stage_runner(
        fn -> insert(repo, changes_list, insert_options) end,
        :block_referencing,
        :token_instances,
        :token_instances
      )
    end)
  end

  @impl Import.Runner
  def timeout, do: @timeout

  @spec insert(Repo.t(), [map()], %{
          optional(:on_conflict) => Import.Runner.on_conflict(),
          required(:timeout) => timeout,
          required(:timestamps) => Import.timestamps()
        }) ::
          {:ok, [TokenInstance.t()]}
          | {:error, [Changeset.t()]}
  def insert(repo, changes_list, %{timeout: timeout, timestamps: timestamps} = options) when is_list(changes_list) do
    on_conflict = Map.get_lazy(options, :on_conflict, &default_on_conflict/0)

    # Guarantee the same import order to avoid deadlocks
    ordered_changes_list = Enum.sort_by(changes_list, &{&1.token_contract_address_hash, &1.token_id})

    {:ok, _} =
      Import.insert_changes_list(
        repo,
        ordered_changes_list,
        conflict_target: [:token_contract_address_hash, :token_id],
        on_conflict: on_conflict,
        for: TokenInstance,
        returning: true,
        timeout: timeout,
        timestamps: timestamps
      )
  end

  defp default_on_conflict do
    from(
      token_instance in TokenInstance,
      update: [
        set: [
          metadata: token_instance.metadata,
          error: token_instance.error,
          owner_updated_at_block: fragment("EXCLUDED.owner_updated_at_block"),
          owner_updated_at_log_index: fragment("EXCLUDED.owner_updated_at_log_index"),
          owner_address_hash: fragment("EXCLUDED.owner_address_hash"),
          inserted_at: fragment("LEAST(?, EXCLUDED.inserted_at)", token_instance.inserted_at),
          updated_at: fragment("GREATEST(?, EXCLUDED.updated_at)", token_instance.updated_at)
        ]
      ],
      where:
        fragment("EXCLUDED.owner_address_hash IS NOT NULL") and fragment("EXCLUDED.owner_updated_at_block IS NOT NULL") and
          (fragment("EXCLUDED.owner_updated_at_block > ?", token_instance.owner_updated_at_block) or
             (fragment("EXCLUDED.owner_updated_at_block = ?", token_instance.owner_updated_at_block) and
                fragment("EXCLUDED.owner_updated_at_log_index >= ?", token_instance.owner_updated_at_log_index)) or
             is_nil(token_instance.owner_updated_at_block) or is_nil(token_instance.owner_address_hash))
    )
  end
end
