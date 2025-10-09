defmodule Explorer.Chain.Import.Runner.Scroll.L1FeeParams do
  @moduledoc """
  Bulk imports `Explorer.Chain.Scroll.L1FeeParam`.
  """

  require Ecto.Query

  alias Ecto.{Changeset, Multi, Repo}
  alias Explorer.Chain.Import
  alias Explorer.Chain.Scroll.L1FeeParam
  alias Explorer.Prometheus.Instrumenter

  import Ecto.Query, only: [from: 2]

  @behaviour Import.Runner

  # milliseconds
  @timeout 60_000

  @type imported :: [L1FeeParam.t()]

  @impl Import.Runner
  def ecto_schema_module, do: L1FeeParam

  @impl Import.Runner
  def option_key, do: :scroll_l1_fee_params

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

    Multi.run(multi, :insert_l1_fee_params, fn repo, _ ->
      Instrumenter.block_import_stage_runner(
        fn -> insert(repo, changes_list, insert_options) end,
        :block_referencing,
        :scroll_l1_fee_params,
        :scroll_l1_fee_params
      )
    end)
  end

  @impl Import.Runner
  def timeout, do: @timeout

  @spec insert(Repo.t(), [map()], %{required(:timeout) => timeout(), required(:timestamps) => Import.timestamps()}) ::
          {:ok, [L1FeeParam.t()]}
          | {:error, [Changeset.t()]}
  def insert(repo, changes_list, %{timeout: timeout, timestamps: timestamps} = options) when is_list(changes_list) do
    on_conflict = Map.get_lazy(options, :on_conflict, &default_on_conflict/0)

    # Enforce L1FeeParam ShareLocks order (see docs: sharelock.md)
    ordered_changes_list = Enum.sort_by(changes_list, &{&1.block_number, &1.transaction_index, &1.name})

    {:ok, inserted} =
      Import.insert_changes_list(
        repo,
        ordered_changes_list,
        for: L1FeeParam,
        returning: true,
        timeout: timeout,
        timestamps: timestamps,
        conflict_target: [:block_number, :transaction_index, :name],
        on_conflict: on_conflict
      )

    {:ok, inserted}
  end

  defp default_on_conflict do
    from(
      param in L1FeeParam,
      update: [
        set: [
          # Don't update `block_number` as it is part of the composite primary key and used for the conflict target
          # Don't update `transaction_index` as it is part of the composite primary key and used for the conflict target
          # Don't update `name` as it is part of the composite primary key and used for the conflict target
          value: fragment("EXCLUDED.value"),
          inserted_at: fragment("LEAST(?, EXCLUDED.inserted_at)", param.inserted_at),
          updated_at: fragment("GREATEST(?, EXCLUDED.updated_at)", param.updated_at)
        ]
      ],
      where:
        fragment(
          "(EXCLUDED.value) IS DISTINCT FROM (?)",
          param.value
        )
    )
  end
end
