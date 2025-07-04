defmodule Explorer.Chain.Import.Runner.SignedAuthorizations do
  @moduledoc """
  Bulk imports `t:Explorer.Chain.SignedAuthorization.t/0`.
  """

  require Ecto.Query

  import Ecto.Query, only: [from: 2]

  alias Ecto.{Changeset, Multi, Repo}
  alias Explorer.Chain.{Import, SignedAuthorization}
  alias Explorer.Prometheus.Instrumenter

  @behaviour Import.Runner

  # milliseconds
  @timeout 60_000

  @type imported :: [SignedAuthorization.t()]

  @impl Import.Runner
  def ecto_schema_module, do: SignedAuthorization

  @impl Import.Runner
  def option_key, do: :signed_authorizations

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

    Multi.run(multi, :signed_authorizations, fn repo, _ ->
      Instrumenter.block_import_stage_runner(
        fn -> insert(repo, changes_list, insert_options) end,
        :block_referencing,
        :signed_authorizations,
        :signed_authorizations
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
          {:ok, [SignedAuthorization.t()]}
          | {:error, [Changeset.t()]}
  defp insert(repo, changes_list, %{timeout: timeout, timestamps: timestamps} = options) when is_list(changes_list) do
    on_conflict = Map.get_lazy(options, :on_conflict, &default_on_conflict/0)
    conflict_target = [:transaction_hash, :index]
    ordered_changes_list = Enum.sort_by(changes_list, &{&1.transaction_hash, &1.index})

    {:ok, _} =
      Import.insert_changes_list(
        repo,
        ordered_changes_list,
        for: SignedAuthorization,
        on_conflict: on_conflict,
        conflict_target: conflict_target,
        returning: true,
        timeout: timeout,
        timestamps: timestamps
      )
  end

  defp default_on_conflict do
    from(
      authorization in SignedAuthorization,
      update: [
        set: [
          chain_id: fragment("EXCLUDED.chain_id"),
          address: fragment("EXCLUDED.address"),
          nonce: fragment("EXCLUDED.nonce"),
          r: fragment("EXCLUDED.r"),
          s: fragment("EXCLUDED.s"),
          v: fragment("EXCLUDED.v"),
          authority: fragment("EXCLUDED.authority"),
          status: fragment("EXCLUDED.status"),
          inserted_at: fragment("LEAST(?, EXCLUDED.inserted_at)", authorization.inserted_at),
          updated_at: fragment("GREATEST(?, EXCLUDED.updated_at)", authorization.updated_at)
        ]
      ],
      where:
        fragment(
          "(EXCLUDED.chain_id, EXCLUDED.address, EXCLUDED.nonce, EXCLUDED.r, EXCLUDED.s, EXCLUDED.v, EXCLUDED.authority, EXCLUDED.status) IS DISTINCT FROM (?, ?, ?, ?, ?, ?, ?, ?)",
          authorization.chain_id,
          authorization.address,
          authorization.nonce,
          authorization.r,
          authorization.s,
          authorization.v,
          authorization.authority,
          authorization.status
        )
    )
  end
end
